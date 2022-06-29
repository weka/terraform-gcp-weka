package terminate

import (
	compute "cloud.google.com/go/compute/apiv1"
	"cloud.google.com/go/firestore"
	"context"
	"encoding/json"
	"errors"
	firebase "firebase.google.com/go"
	"fmt"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/cloud-functions/protocol"
	"google.golang.org/api/iterator"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
	"net/http"
	"os"
	"strings"
	"time"
)

type Nilt struct{}

var Nilv = Nilt{}

type instancesMap map[string]*computepb.Instance
type InstanceIdsSet map[string]Nilt
type InstancePrivateIpsSet map[string]Nilt

var Project = os.Getenv("PROJECT")
var Zone = os.Getenv("ZONE")

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

func generateInstanceNamesFilter(instanceNames []string) (namesFilter string) {
	if len(instanceNames) == 0 {
		log.Fatal().Err(errors.New("no instances found in instance group"))
	}

	namesFilter = fmt.Sprintf("name=%s", instanceNames[0])
	for _, instanceName := range instanceNames[1:] {
		namesFilter = fmt.Sprintf("%s OR name=%s", namesFilter, instanceName)
	}
	log.Info().Msgf("%s", namesFilter)
	return
}

func getInstances(instanceIds []string) (instances []*computepb.Instance, err error) {
	idsFilter := generateInstanceNamesFilter(instanceIds)

	ctx := context.Background()
	instanceClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Fatal().Err(err)
	}
	defer instanceClient.Close()

	listInstanceRequest := &computepb.ListInstancesRequest{
		Project: Project,
		Zone:    Zone,
		Filter:  &idsFilter,
	}

	listInstanceIter := instanceClient.List(ctx, listInstanceRequest)

	for {
		resp, err := listInstanceIter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Error().Msgf("%s", err)
			return nil, err
		}
		log.Info().Msgf("%s %d %s", *resp.Name, resp.Id, *resp.NetworkInterfaces[0].NetworkIP)
		instances = append(instances, resp)
	}
	return
}

func getDeltaInstancesIds(asgInstanceIds []string, scaleResponse protocol.ScaleResponse) (deltaInstanceIDs []string, err error) {
	log.Info().Msg("Getting delta instances")
	asgInstances, err := getInstances(asgInstanceIds)
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

func terminateInstances(instanceIds []string) (terminatingInstances []string, errs []error) {

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
			Project:  Project,
			Zone:     Zone,
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

func terminateUnneededInstances(asgName string, instances []*computepb.Instance, explicitRemoval []protocol.HgInstance) (terminated []*computepb.Instance, errs []error) {
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

	terminatedInstances, errs := terminateAsgInstances(asgName, terminateInstanceIds)

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

func terminateAsgInstances(asgName string, terminateInstanceIds []string) (terminatedInstances []string, errs []error) {
	if len(terminateInstanceIds) == 0 {
		return
	}
	setToTerminate := terminateInstanceIds[:min(len(terminateInstanceIds), 50)]
	for _, instanceId := range setToTerminate {
		err := unsetDeletionProtection(Project, Zone, instanceId)
		if err != nil {
			errs = append(errs, err)
		}
	}

	terminatedInstances, errs = terminateInstances(setToTerminate)
	return
}

func getAsgInstances(project, zone, instanceGroup string) (instances []*computepb.InstanceWithNamedPorts) {
	ctx := context.Background()

	c, err := compute.NewInstanceGroupsRESTClient(ctx)
	if err != nil {
		log.Fatal().Err(err)
	}
	defer c.Close()

	req := &computepb.ListInstancesInstanceGroupsRequest{
		Project:       project,
		Zone:          zone,
		InstanceGroup: instanceGroup,
	}
	it := c.ListInstances(ctx, req)

	for {
		resp, err := it.Next()

		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Error().Msgf("%s", err)
			return
		}

		instances = append(instances, resp)
	}
	return
}

func unpackASGInstanceIds(instances []*computepb.InstanceWithNamedPorts) (instanceIds []string) {
	for _, instance := range instances {
		split := strings.Split(*instance.Instance, "/")
		instanceIds = append(instanceIds, split[len(split)-1])
	}
	return
}

//func InstanceIdsToNames(instanceIds []string) (instanceNames []string) {
//
//	for _, instance := range instanceIds {
//		//split := strings.Split(instance.Instance, "/")
//		//instanceNames = append(instanceNames, split[len(split)-1])
//	}
//	return
//}

func getInstanceGroupInstances(project, zone string, instanceNames []string) (instances []*computepb.Instance) {
	namesFilter := generateInstanceNamesFilter(instanceNames)

	ctx := context.Background()
	instanceClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Fatal().Err(err)
	}
	defer instanceClient.Close()

	listInstanceRequest := &computepb.ListInstancesRequest{
		Project: project,
		Zone:    zone,
		Filter:  &namesFilter,
	}

	listInstanceIter := instanceClient.List(ctx, listInstanceRequest)

	for {
		resp, err := listInstanceIter.Next()

		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Error().Msgf("%s", err)
			return
		}
		log.Info().Msgf("%s %d %s", *resp.Name, resp.Id, *resp.NetworkInterfaces[0].NetworkIP)
		instances = append(instances, resp)
	}
	return
}

func writeResponse(w http.ResponseWriter, response protocol.TerminatedInstancesResponse) {
	fmt.Println("Writing Terminate result")
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

func decrement(project, collectionName, documentName string, amount int) (err error) {
	log.Info().Msg("updating DB")

	ctx := context.Background()
	conf := &firebase.Config{ProjectID: project}
	app, err := firebase.NewApp(ctx, conf)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}

	client, err := app.Firestore(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}
	defer client.Close()
	doc := client.Collection(collectionName).Doc(documentName)

	_, err = doc.Update(ctx, []firestore.Update{
		{Path: "counter", Value: firestore.Increment(amount * -1)},
	})

	if err != nil {
		log.Error().Msgf("Failed updating db: %s", err)
	}

	return
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
	_, terminateErrors := terminateInstances(toTerminate)
	errs = append(errs, terminateErrors...)

	return
}

func Terminate(w http.ResponseWriter, scaleResponse protocol.ScaleResponse, project, collectionName, documentName, loadBalancerName string) {
	var response protocol.TerminatedInstancesResponse
	var err error

	response.Version = protocol.Version

	if scaleResponse.Version != protocol.Version {
		log.Error().Msgf("Incompatible scale response version")
		writeResponse(w, response)
		return
	}

	instanceGroup := os.Getenv("INSTANCE_GROUP")
	if instanceGroup == "" {
		log.Error().Msgf("ASG_NAME env var is mandatory")
		writeResponse(w, response)
		return
	}
	response.TransientErrors = scaleResponse.TransientErrors[0:len(scaleResponse.TransientErrors):len(scaleResponse.TransientErrors)]

	asgInstances := getAsgInstances(Project, Zone, instanceGroup)
	asgInstanceIds := unpackASGInstanceIds(asgInstances)
	log.Info().Msgf("Found %d instances on ASG", len(asgInstanceIds))
	if err != nil {
		log.Error().Msgf("%s", err)
		writeResponse(w, response)
		return
	}

	errs := TerminateUnhealthyInstances(Project, Zone, instanceGroup, loadBalancerName)
	if len(errs) != 0 {
		response.AddTransientErrors(errs)
	}

	deltaInstanceIds, err := getDeltaInstancesIds(asgInstanceIds, scaleResponse)
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

	candidatesToTerminate, err := getInstances(deltaInstanceIds)
	if err != nil {
		log.Error().Msgf("%s", err)
		writeResponse(w, response)
		return
	}

	terminatedInstances, errs := terminateUnneededInstances(instanceGroup, candidatesToTerminate, scaleResponse.ToTerminate)
	response.AddTransientErrors(errs)

	decrement(project, collectionName, documentName, len(terminatedInstances))

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
