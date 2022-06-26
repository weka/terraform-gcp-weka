package scale_up

import (
	compute "cloud.google.com/go/compute/apiv1"
	"context"
	firebase "firebase.google.com/go"
	"fmt"
	"github.com/google/uuid"
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

func getClusterSizeInfo(project, collectionName, documentName string) (info map[string]interface{}) {
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
	doc := client.Collection(collectionName).Doc(documentName)
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

	_, err = instancesClient.Insert(ctx, req)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}

	return
}

func ScaleUp(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	instanceGroup := os.Getenv("INSTANCE_GROUP")
	backendTemplate := os.Getenv("BACKEND_TEMPLATE")
	clusterizeTemplate := os.Getenv("CLUSTERIZE_TEMPLATE")
	joinTemplate := os.Getenv("JOIN_TEMPLATE")
	collectionName := os.Getenv("COLLECTION_NAME")
	documentName := os.Getenv("DOCUMENT_NAME")

	instanceGroupSize := getInstanceGroupSize(project, zone, instanceGroup)
	log.Info().Msgf("Instance group size is: %d", instanceGroupSize)
	clusterInfo := getClusterSizeInfo(project, collectionName, documentName)
	initialSize := int32(clusterInfo["initial_size"].(int64))
	desiredSize := int32(clusterInfo["desired_size"].(int64))
	counter := int32(clusterInfo["counter"].(int64))
	log.Info().Msgf("Desired size is: %d", desiredSize)

	if counter >= initialSize {
		if desiredSize > counter {
			for i := counter; i < desiredSize; i++ {
				instanceName := fmt.Sprintf("weka-%s", uuid.New().String())
				log.Info().Msg("weka is clusterized joining new instance")
				if err := createInstance(project, zone, joinTemplate, instanceGroup, instanceName); err != nil {
					fmt.Fprintf(w, "Instance %s creation failed %s.", instanceName, err)
				} else {
					fmt.Fprintf(w, "Instance %s join has started.", instanceName)
				}
			}
			return
		}
	} else {
		i := counter
		for ; i < initialSize-1; i++ {
			instanceName := fmt.Sprintf("weka-%d", i)
			log.Info().Msg("weka is not clusterized, creating new instance")
			if err := createInstance(project, zone, backendTemplate, instanceGroup, instanceName); err != nil {
				fmt.Fprintf(w, "Instance %s creation failed %s.", instanceName, err)
			} else {
				fmt.Fprintf(w, "Backend instance %s was created successfully.", instanceName)

			}
		}
		instanceName := fmt.Sprintf("weka-%d", i)
		log.Info().Msg("weka is not clusterized, creating new instance and clusterizing")
		if err := createInstance(project, zone, clusterizeTemplate, instanceGroup, instanceName); err != nil {
			fmt.Fprintf(w, "Instance %s creation failed %s", instanceName, err)
		} else {
			fmt.Fprintf(w, "Backend instance %s was created successfully, clusterization has started", instanceName)
		}
		return
	}

	fmt.Fprintf(w, "Nothing to do!")
}
