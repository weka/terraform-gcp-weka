package bunch

import (
	compute "cloud.google.com/go/compute/apiv1"
	"context"
	"fmt"
	"github.com/rs/zerolog/log"
	"google.golang.org/api/iterator"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
	"net/http"
	"os"
	"strings"
)

func getAsgInstances(project, zone, instanceGroup string) (instancesNames []string) {
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
		split := strings.Split(*resp.Instance, "/")
		instancesNames = append(instancesNames, split[len(split)-1])
	}
	return
}

func getBackendsNames(project, zone, clusterName string) (backendsNames []string) {
	ctx := context.Background()
	instanceClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
	}
	defer instanceClient.Close()

	clusterNameFilter := fmt.Sprintf("labels.cluster_name=%s", clusterName)
	listInstanceRequest := &computepb.ListInstancesRequest{
		Project: project,
		Zone:    zone,
		Filter:  &clusterNameFilter,
	}

	listInstanceIter := instanceClient.List(ctx, listInstanceRequest)

	for {
		resp, err := listInstanceIter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Error().Msgf("%s", err)
			break
		}
		backendsNames = append(backendsNames, *resp.Name)
	}
	return
}

func contains(s []string, str string) bool {
	for _, v := range s {
		if v == str {
			return true
		}
	}

	return false
}

func getInstancesToAdd(project, zone, clusterName, instanceGroup string) (instancesNames []string) {
	backendsNames := getBackendsNames(project, zone, clusterName)
	instanceGroupBackendsNames := getAsgInstances(project, zone, instanceGroup)
	for _, name := range backendsNames {
		if !contains(instanceGroupBackendsNames, name) {
			instancesNames = append(instancesNames, name)
		}
	}
	log.Debug().Msgf("Instances to add: %s", instancesNames)
	return
}

func addInstanceToGroup(project, zone, instanceGroup, instanceName string) {
	log.Info().Msgf("Adding instance %s to instance group successfully", instanceName)
	ctx := context.Background()
	instancesClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}
	defer instancesClient.Close()

	instance, err := instancesClient.Get(ctx, &computepb.GetInstanceRequest{
		Instance: instanceName,
		Project:  project,
		Zone:     zone,
	})
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}

	instancesGroupClient, err := compute.NewInstanceGroupsRESTClient(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}
	defer instancesGroupClient.Close()
	_, err = instancesGroupClient.AddInstances(ctx, &computepb.AddInstancesInstanceGroupRequest{
		InstanceGroup: instanceGroup,
		InstanceGroupsAddInstancesRequestResource: &computepb.InstanceGroupsAddInstancesRequest{
			Instances: []*computepb.InstanceReference{&computepb.InstanceReference{Instance: instance.SelfLink}},
		},
		Project: project,
		Zone:    zone,
	})

	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}

	log.Info().Msgf("Instance %s was added to instance group successfully", instanceName)
}

func addInstancesToGroup(project, zone, clusterName, instanceGroup string) (instancesNames []string) {
	instancesNames = getInstancesToAdd(project, zone, clusterName, instanceGroup)
	for _, instanceName := range instancesNames {
		addInstanceToGroup(project, zone, instanceGroup, instanceName)
	}
	return
}

func Bunch(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	clusterName := os.Getenv("CLUSTER_NAME")
	fmt.Fprintf(w, "Added %s to instance group", addInstancesToGroup(project, zone, clusterName, instanceGroup))
}
