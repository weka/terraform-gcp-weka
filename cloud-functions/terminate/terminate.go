package terminate

import (
	compute "cloud.google.com/go/compute/apiv1"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/cloud-functions/terminate/protocol"
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

func terminateInstances(instanceIds []string) (terminatingInstances []string, err error) {

	ctx := context.Background()
	instanceClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Fatal().Err(err)
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

func terminateAsgInstances(asgName string, terminateInstanceIds []string) (terminatedInstances []string, errs []error) {
	if len(terminateInstanceIds) == 0 {
		return
	}
	//setToTerminate, errs := common.SetDisableInstancesApiTermination(
	//	terminateInstanceIds[:common.Min(len(terminateInstanceIds), 50)],
	//	false,
	//)
	//
	//err := removeAutoScalingProtection(asgName, setToTerminate)
	//if err != nil {
	//	// WARNING: This is debatable if error here is transient or not
	//	//	Specifically now we can return empty list of what we were able to terminate because this API call failed
	//	//   But in future with adding more lambdas into state machine this might become wrong decision
	//	log.Error().Err(err)
	//	setToTerminate = setToTerminate[:0]
	//	errs = append(errs, err)
	//}

	setToTerminate := terminateInstanceIds
	terminatedInstances, err := terminateInstances(setToTerminate)
	if err != nil {
		log.Error().Err(err)
		errs = append(errs, err)
		return
	}
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

func Terminate(w http.ResponseWriter, r *http.Request) {

	var response protocol.TerminatedInstancesResponse
	var err error
	var scaleResponse protocol.ScaleResponse
	if err := json.NewDecoder(r.Body).Decode(&scaleResponse); err != nil {
		fmt.Fprint(w, "Failed decoding request body")
		return
	}
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

	//errs := detachUnhealthyInstances(asgInstances, instanceGroup)
	//if len(errs) != 0 {
	//	response.AddTransientErrors(errs)
	//}

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
}

//
//func detachUnhealthyInstances(instances []*computepb.InstanceWithNamedPorts, asgName string) (errs []error) {
//	toDetach := []string{}
//	toTerminate := []string{}
//	for _, instance := range instances {
//		if *instance.Status == "UNHEALTHY" {
//			log.Info().Msgf("handling unhealthy instance %s", *instance.InstanceId)
//			toDelete := false
//			if !*instance.ProtectedFromScaleIn {
//				toDelete = true
//			}
//
//			if !toDelete {
//				instances, ec2err := common.GetInstances([]*string{instance.InstanceId})
//				if ec2err != nil {
//					errs = append(errs, ec2err)
//					continue
//				}
//				if len(instances) == 0 {
//					log.Debug().Msgf("didn't find instance %s, assuming it is terminated", *instance.InstanceId)
//					toDelete = true
//				} else {
//					inst := instances[0]
//					log.Debug().Msgf("instance state: %s", *inst.State.Name)
//					if *inst.State.Name == ec2.InstanceStateNameStopped {
//						toTerminate = append(toTerminate, *inst.InstanceId)
//					}
//					if *inst.State.Name == ec2.InstanceStateNameTerminated {
//						toDelete = true
//					}
//				}
//
//			}
//			if toDelete {
//				log.Info().Msgf("detaching %s", *instance.InstanceId)
//				toDetach = append(toDetach, *instance.InstanceId)
//			}
//		}
//	}
//
//	log.Debug().Msgf("found %d stopped instances", len(toTerminate))
//	terminatedInstances, terminateErrors := terminateAsgInstances(asgName, toTerminate)
//	errs = append(errs, terminateErrors...)
//	for _, inst := range terminatedInstances {
//		log.Info().Msgf("detaching %s", inst)
//		toDetach = append(toDetach, inst)
//	}
//
//	if len(toDetach) == 0 {
//		return nil
//	}
//
//	err := autoscaling2.DetachInstancesFromASG(toDetach, asgName)
//	if err != nil {
//		errs = append(errs, err)
//	}
//	return
//}
