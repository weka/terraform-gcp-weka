package bunch

import (
	compute "cloud.google.com/go/compute/apiv1"
	"context"
	"github.com/rs/zerolog/log"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
)

func AddInstanceToGroup(project, zone, instanceGroup, instanceName string) (err error) {
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
	return
}
