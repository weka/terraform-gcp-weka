package protect

import (
	compute "cloud.google.com/go/compute/apiv1"
	"context"
	"github.com/rs/zerolog/log"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
)

func SetDeletionProtection(project, zone, instanceName string) (err error) {
	log.Info().Msgf("Setting deletion protection on %s", instanceName)
	ctx := context.Background()

	c, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}
	defer c.Close()

	value := true
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
