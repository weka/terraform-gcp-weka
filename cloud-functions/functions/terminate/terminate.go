package terminate

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	compute "cloud.google.com/go/compute/apiv1"
	"cloud.google.com/go/compute/apiv1/computepb"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/go-cloud-lib/protocol"
)

type Nilt struct{}

var Nilv = Nilt{}

type instancesMap map[string]*computepb.Instance
type InstanceIdsSet map[string]Nilt
type InstancePrivateIpsSet map[string]Nilt

func getInstancePrivateIpsSet(scaleResponse protocol.ScaleResponse) InstancePrivateIpsSet {
	instancePrivateIpsSet := make(InstancePrivateIpsSet)
	for _, instance := range scaleResponse.Hosts {
		instancePrivateIpsSet[instance.PrivateIp] = Nilv
	}
	return instancePrivateIpsSet
}

func instancesToMap(instances []*computepb.Instance) instancesMap {
	im := make(instancesMap)
	for _, instance := range instances {
		im[*instance.Name] = instance
	}
	return im
}

func getDeltaInstancesIds(ctx context.Context, project, zone string, asgInstanceIds []string, scaleResponse protocol.ScaleResponse) (deltaInstanceIDs []string, err error) {
	log.Info().Msg("Getting delta instances")
	asgInstances, err := common.GetInstances(ctx, project, zone, asgInstanceIds)
	if err != nil {
		return
	}
	instancePrivateIpsSet := getInstancePrivateIpsSet(scaleResponse)

	for _, instance := range asgInstances {
		log.Info().Msgf("Checking %s %s", *instance.Name, *instance.NetworkInterfaces[0].NetworkIP)
		if instance.NetworkInterfaces[0].NetworkIP == nil {
			continue
		}
		if _, ok := instancePrivateIpsSet[*instance.NetworkInterfaces[0].NetworkIP]; !ok {
			deltaInstanceIDs = append(deltaInstanceIDs, *instance.Name)
		}
	}
	log.Info().Msgf("Delta instances%s", deltaInstanceIDs)
	return
}

func setForExplicitRemoval(instance *computepb.Instance, toRemove []protocol.HgInstance) bool {
	for _, i := range toRemove {
		if *instance.NetworkInterfaces[0].NetworkIP == i.PrivateIp && *instance.SelfLink == i.Id {
			return true
		}
	}
	return false
}

func terminateUnneededInstances(ctx context.Context, project, zone string, instances []*computepb.Instance, explicitRemoval []protocol.HgInstance) (terminated []*computepb.Instance, errs []error) {
	terminateInstanceIds := make([]string, 0, 0)
	imap := instancesToMap(instances)

	for _, instance := range instances {
		if !setForExplicitRemoval(instance, explicitRemoval) {
			date, err := time.Parse(time.RFC3339, *instance.CreationTimestamp)

			if err != nil {
				log.Error().Msgf("error formatting creation time %s", err.Error())
				errs = append(errs, err)
				continue
			}
			if time.Now().Sub(date) < time.Minute*30 {
				continue
			}
		}
		instanceState := *instance.Status
		if instanceState != "STOPPING" && instanceState != "TERMINATED" {
			terminateInstanceIds = append(terminateInstanceIds, *instance.Name)
		}
	}

	terminatedInstances, errs := terminateAsgInstances(ctx, project, zone, terminateInstanceIds)

	for _, id := range terminatedInstances {
		terminated = append(terminated, imap[id])
	}
	return
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func terminateAsgInstances(ctx context.Context, project, zone string, terminateInstanceIds []string) (terminatedInstances []string, errs []error) {
	if len(terminateInstanceIds) == 0 {
		return
	}
	setToTerminate := terminateInstanceIds[:min(len(terminateInstanceIds), 50)]
	for _, instanceId := range setToTerminate {
		err := common.UnsetDeletionProtection(ctx, project, zone, instanceId)
		if err != nil {
			errs = append(errs, err)
		}
	}

	terminatedInstances, errs = common.TerminateInstances(ctx, project, zone, setToTerminate)
	return
}

func writeResponse(w http.ResponseWriter, response protocol.TerminatedInstancesResponse) {
	fmt.Println("Writing Terminate result")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func TerminateUnhealthyInstances(ctx context.Context, project, zone, instanceGroup, loadBalancerName string) (errs []error) {
	var toTerminate []string

	c, err := compute.NewRegionBackendServicesRESTClient(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		errs = append(errs, err)
		return
	}
	defer c.Close()

	instanceGroupClient, err := compute.NewInstanceGroupsRESTClient(ctx)
	if err != nil {
		log.Fatal().Err(err)
		errs = append(errs, err)
		return
	}
	defer instanceGroupClient.Close()

	instanceGroupObject, err := instanceGroupClient.Get(ctx, &computepb.GetInstanceGroupRequest{
		Project:       project,
		Zone:          zone,
		InstanceGroup: instanceGroup,
	})
	if err != nil {
		err = fmt.Errorf("error getting instance group: %w", err)
		log.Fatal().Err(err)
		errs = append(errs, err)
		return
	}

	req := &computepb.GetHealthRegionBackendServiceRequest{
		Project:        project,
		Region:         zone[:len(zone)-2],
		BackendService: loadBalancerName,
		ResourceGroupReferenceResource: &computepb.ResourceGroupReference{
			Group: instanceGroupObject.SelfLink,
		},
	}

	resp, err := c.GetHealth(ctx, req)
	if err != nil {
		err = fmt.Errorf("error getting health status: %s", err)
		log.Error().Err(err).Send()
		errs = append(errs, err)
		return
	}

	instancesClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		err = fmt.Errorf("error getting instances client: %s", err)
		log.Error().Err(err).Send()
		return
	}
	defer instancesClient.Close()

	for _, healthStatus := range resp.HealthStatus {
		instanceNameParts := strings.Split(*healthStatus.Instance, "/")
		instanceName := instanceNameParts[len(instanceNameParts)-1]
		log.Info().Msgf("handling instance %s(%s)", instanceName, *healthStatus.HealthState)
		if *healthStatus.HealthState == "UNHEALTHY" {
			instance, err := instancesClient.Get(ctx, &computepb.GetInstanceRequest{
				Instance: instanceName,
				Project:  project,
				Zone:     zone,
			})
			if err != nil {
				log.Error().Msgf("%s", err)
				return
			}

			log.Debug().Msgf("instance state: %s", *instance.Status)
			if *instance.Status == "SUSPENDED" {
				toTerminate = append(toTerminate, instanceName)
			}

		}
	}

	log.Debug().Msgf("found %d suspended instances", len(toTerminate))
	_, terminateErrors := common.TerminateInstances(ctx, project, zone, toTerminate)
	errs = append(errs, terminateErrors...)

	return
}

func Terminate(
	ctx context.Context, scaleResponse protocol.ScaleResponse, project, zone, instanceGroup, loadBalancerName string,
) (response protocol.TerminatedInstancesResponse, err error) {
	response.Version = protocol.Version

	if scaleResponse.Version != protocol.Version {
		err = errors.New("incompatible scale response version")
		return
	}

	if instanceGroup == "" {
		err = errors.New("instance group is mandatory")
		return
	}
	if len(scaleResponse.Hosts) == 0 {
		err = errors.New("hosts list must not be empty")
		return
	}

	response.TransientErrors = scaleResponse.TransientErrors[0:len(scaleResponse.TransientErrors):len(scaleResponse.TransientErrors)]

	asgInstanceIds := common.GetInstanceGroupInstanceNames(ctx, project, zone, instanceGroup)
	log.Info().Msgf("Found %d instances on ASG", len(asgInstanceIds))
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}

	errs := TerminateUnhealthyInstances(ctx, project, zone, instanceGroup, loadBalancerName)
	if len(errs) != 0 {
		log.Warn().Msgf("errors while terminating unhealthy instances: %s", errs)
		response.AddTransientErrors(errs)
	}

	deltaInstanceIds, err := getDeltaInstancesIds(ctx, project, zone, asgInstanceIds, scaleResponse)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}

	if len(deltaInstanceIds) == 0 {
		log.Info().Msgf("No delta instances ids")
		return
	}

	candidatesToTerminate, err := common.GetInstances(ctx, project, zone, deltaInstanceIds)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}

	terminatedInstances, errs := terminateUnneededInstances(ctx, project, zone, candidatesToTerminate, scaleResponse.ToTerminate)
	if len(errs) != 0 {
		log.Warn().Msgf("errors while terminating unneeded instances: %s", errs)
		response.AddTransientErrors(errs)
	}

	//detachTerminated(asgName)

	for _, instance := range terminatedInstances {
		date, err := time.Parse(time.RFC3339, *instance.CreationTimestamp)

		if err != nil {
			log.Error().Msgf("error formatting creation time %s", err.Error())
			continue
		}

		response.Instances = append(response.Instances, protocol.TerminatedInstance{
			InstanceId: *instance.Name,
			Creation:   date,
		})
	}

	return
}
