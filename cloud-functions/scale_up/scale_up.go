package scale_up

import (
	compute "cloud.google.com/go/compute/apiv1"
	"context"
	firebase "firebase.google.com/go"
	"github.com/rs/zerolog/log"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
	"google.golang.org/protobuf/proto"
)

func GetInstanceGroupSize(project, zone, instanceGroup string) int32 {
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

func GetClusterSizeInfo(project, collectionName, documentName string) (info map[string]interface{}) {
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

func CreateInstance(project, zone, template, instanceGroup, instanceName string) (err error) {
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
