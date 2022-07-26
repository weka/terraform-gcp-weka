package terminate

import (
	compute "cloud.google.com/go/compute/apiv1"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/protocol"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
	"net/http"
	"strings"
	"time"
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

func getDeltaInstancesIds(project, zone string, asgInstanceIds []string, scaleResponse protocol.ScaleResponse) (deltaInstanceIDs []string, err error) {
	log.Info().Msg("Getting delta instances")
	asgInstances, err := common.GetInstances(project, zone, asgInstanceIds)
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

func terminateInstances(project, zone string, instanceIds []string) (terminatingInstances []string, errs []error) {

	ctx := context.Background()
	instanceClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Fatal().Err(err)
		errs = append(errs, err)
		return
	}
	defer instanceClient.Close()

	log.Info().Msgf("Terminating instances %s", instanceIds)
	for _, instanceId := range instanceIds {
		_, err := instanceClient.Delete(ctx, &computepb.DeleteInstanceRequest{
			Project:  project,
			Zone:     zone,
			Instance: instanceId,
		})
		if err != nil {
			log.Error().Msgf("error terminating instances %s", err.Error())
			errs = append(errs, err)
			continue
		}
		terminatingInstances = append(terminatingInstances, instanceId)
	}
	return
}

func terminateUnneededInstances(project, zone string, instances []*computepb.Instance, explicitRemoval []protocol.HgInstance) (terminated []*computepb.Instance, errs []error) {
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

	terminatedInstances, errs := terminateAsgInstances(project, zone, terminateInstanceIds)

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

func unsetDeletionProtection(project, zone, instanceName string) (err error) {
	log.Info().Msgf("Setting deletion protection on %s", instanceName)
	ctx := context.Background()

	c, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}
	defer c.Close()

	value := false
	req := &computepb.SetDeletionProtectionInstanceRequest{
		Project:            project,
		Zone:               zone,
		Resource:           instanceName,
		DeletionProtection: &value,
	}

	_, err = c.SetDeletionProtection(ctx, req)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}

	return
}

func terminateAsgInstances(project, zone string, terminateInstanceIds []string) (terminatedInstances []string, errs []error) {
	if len(terminateInstanceIds) == 0 {
		return
	}
	setToTerminate := terminateInstanceIds[:min(len(terminateInstanceIds), 50)]
	for _, instanceId := range setToTerminate {
		err := unsetDeletionProtection(project, zone, instanceId)
		if err != nil {
			errs = append(errs, err)
		}
	}

	terminatedInstances, errs = terminateInstances(project, zone, setToTerminate)
	return
}

func writeResponse(w http.ResponseWriter, response protocol.TerminatedInstancesResponse) {
	fmt.Println("Writing Terminate result")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func TerminateUnhealthyInstances(project, zone, instanceGroup, loadBalancerName string) (errs []error) {
	var toTerminate []string

	ctx := context.Background()

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
		log.Error().Msgf("%s", err)
		errs = append(errs, err)
		return
	}

	instancesClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
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
	_, terminateErrors := terminateInstances(project, zone, toTerminate)
	errs = append(errs, terminateErrors...)

	return
}

func Terminate(w http.ResponseWriter, scaleResponse protocol.ScaleResponse, project, zone, instanceGroup, loadBalancerName string) (err error) {
	var response protocol.TerminatedInstancesResponse

	response.Version = protocol.Version

	if scaleResponse.Version != protocol.Version {
		err = errors.New("incompatible scale response version")
		writeResponse(w, response)
		return
	}

	if instanceGroup == "" {
		err = errors.New("instance group is mandatory")
		writeResponse(w, response)
		return
	}
	if len(scaleResponse.Hosts) == 0 {
		err = errors.New("hosts list must not be empty")
		writeResponse(w, response)
		return
	}

	response.TransientErrors = scaleResponse.TransientErrors[0:len(scaleResponse.TransientErrors):len(scaleResponse.TransientErrors)]

	asgInstanceIds := common.GetInstanceGroupInstanceNames(project, zone, instanceGroup)
	log.Info().Msgf("Found %d instances on ASG", len(asgInstanceIds))
	if err != nil {
		log.Error().Msgf("%s", err)
		writeResponse(w, response)
		return
	}

	errs := TerminateUnhealthyInstances(project, zone, instanceGroup, loadBalancerName)
	if len(errs) != 0 {
		response.AddTransientErrors(errs)
	}

	deltaInstanceIds, err := getDeltaInstancesIds(project, zone, asgInstanceIds, scaleResponse)
	if err != nil {
		log.Error().Msgf("%s", err)
		writeResponse(w, response)
		return
	}

	if len(deltaInstanceIds) == 0 {
		log.Info().Msgf("No delta instances ids")
		writeResponse(w, response)
		return
	}

	candidatesToTerminate, err := common.GetInstances(project, zone, deltaInstanceIds)
	if err != nil {
		log.Error().Msgf("%s", err)
		writeResponse(w, response)
		return
	}

	terminatedInstances, errs := terminateUnneededInstances(project, zone, candidatesToTerminate, scaleResponse.ToTerminate)
	response.AddTransientErrors(errs)

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

	writeResponse(w, response)

	return
}
