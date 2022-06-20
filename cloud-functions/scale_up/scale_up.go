package scale_up

import (
	compute "cloud.google.com/go/compute/apiv1"
	"context"
	firebase "firebase.google.com/go"
	"fmt"
	"github.com/rs/zerolog/log"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
	"google.golang.org/protobuf/proto"
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

func getClusterSizeInfo(project string) (info map[string]interface{}) {
	log.Info().Msg("Retrieving desired group size from DB")

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
	doc := client.Collection("weka-collection").Doc("weka-document")
	res, err := doc.Get(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}
	return res.Data()
}

func createInstance(project, zone, template, instanceGroup, instanceName string) (err error) {
	ctx := context.Background()
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

	op, err := instancesClient.Insert(ctx, req)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}

	if err = op.Wait(ctx); err != nil {
		log.Error().Msgf("%s", err)
		return
	}
	log.Info().Msgf("Instance creation completed successfully")

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
	op, err = instancesGroupClient.AddInstances(ctx, &computepb.AddInstancesInstanceGroupRequest{
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

	if err = op.Wait(ctx); err != nil {
		log.Error().Msgf("%s", err)
		return
	}
	log.Info().Msgf("Instance was added to instance group successfully")

	return
}

func ScaleUp(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	backendTemplate := os.Getenv("BACKEND_TEMPLATE")
	clusterizeTemplate := os.Getenv("CLUSTERIZE_TEMPLATE")
	joinTemplate := os.Getenv("JOIN_TEMPLATE")

	instanceGroupSize := getInstanceGroupSize(project, zone, instanceGroup)
	log.Info().Msgf("Instance group size is: %d", instanceGroupSize)
	clusterInfo := getClusterSizeInfo(project)
	initialSize := int32(clusterInfo["initial_size"].(int64))
	desiredSize := int32(clusterInfo["desired_size"].(int64))
	log.Info().Msgf("Desired size is: %d", desiredSize)

	instanceName := fmt.Sprintf("weka-%d", instanceGroupSize)
	if clusterInfo["clusterized"].(bool) {
		if desiredSize > instanceGroupSize {
			log.Info().Msg("weka is clusterized joining new instance")
			if err := createInstance(project, zone, joinTemplate, instanceGroup, instanceName); err != nil {
				fmt.Fprintf(w, "Instance %s creation failed %s", instanceName, err)
			} else {
				fmt.Fprintf(w, "Instance %s joined successfully", instanceName)
			}
			return
		}
	} else if initialSize == instanceGroupSize+1 {
		log.Info().Msg("weka is not clusterized, creating new instance and clusterizing")
		if err := createInstance(project, zone, clusterizeTemplate, instanceGroup, instanceName); err != nil {
			fmt.Fprintf(w, "Instance %s creation failed %s", instanceName, err)
		} else {
			fmt.Fprintf(w, "Backend instance %s was created successfully, clusterization has started", instanceName)
		}
		return
	} else {
		log.Info().Msg("weka is not clusterized, creating new instance")
		if err := createInstance(project, zone, backendTemplate, instanceGroup, instanceName); err != nil {
			fmt.Fprintf(w, "Instance %s creation failed %s", instanceName, err)
		} else {
			fmt.Fprintf(w, "Backend instance %s was created successfully", instanceName)
		}
		return
	}

	fmt.Fprintf(w, "Nothing to do!")
}
