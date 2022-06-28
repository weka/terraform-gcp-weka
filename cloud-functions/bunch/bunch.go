package bunch

import (
	compute "cloud.google.com/go/compute/apiv1"
	"context"
	"encoding/json"
	"fmt"
	"github.com/rs/zerolog/log"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
	"net/http"
	"os"
)

func addInstanceToGroup(project, zone, instanceGroup, instanceName string) (err error) {
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

func Bunch(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")

	var d struct {
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&d); err != nil {
		fmt.Fprint(w, "Failed decoding request")
		return
	}
	err := addInstanceToGroup(project, zone, instanceGroup, d.Name)

	if err != nil {
		fmt.Fprintf(w, "%s", err)
	} else {
		fmt.Fprintf(w, "Added %s to instance group %s successfully", d.Name, instanceGroup)
	}
}
