package get_size

import (
	compute "cloud.google.com/go/compute/apiv1"
	"context"
	"fmt"
	"github.com/rs/zerolog/log"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
	"net/http"
	"os"
)

func getInstanceGroupSize(project, zone, instanceGroup string) int32 {
	log.Info().Msg("Retrieving instance group size")
	ctx := context.Background()

	c, err := compute.NewInstanceGroupsRESTClient(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return -1
	}
	defer c.Close()

	req := &computepb.GetInstanceGroupRequest{
		Project:       project,
		Zone:          zone,
		InstanceGroup: instanceGroup,
	}

	resp, err := c.Get(ctx, req)
	if err != nil {
		log.Error().Msgf("%s", err)
		return -1
	}

	return *resp.Size
}

func GetSize(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")

	fmt.Fprintf(w, "%d", getInstanceGroupSize(project, zone, instanceGroup))
}
