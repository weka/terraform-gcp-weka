package scale_up

import (
	compute "cloud.google.com/go/compute/apiv1"
	"cloud.google.com/go/compute/apiv1/computepb"
	"context"
	"github.com/rs/zerolog/log"
	"google.golang.org/protobuf/proto"
)

func CreateInstance(ctx context.Context, project, zone, template, instanceName string) (err error) {
	instancesClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}
	defer instancesClient.Close()

	req := &computepb.InsertInstanceRequest{
		Project: project,
		Zone:    zone,
		InstanceResource: &computepb.Instance{
			Name: proto.String(instanceName),
		},
		SourceInstanceTemplate: &template,
	}

	_, err = instancesClient.Insert(ctx, req)
	if err != nil {
		log.Error().Msgf("Instance creation failed: %s", err)
		return
	}

	return
}
