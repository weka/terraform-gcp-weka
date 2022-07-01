package common

import (
	compute "cloud.google.com/go/compute/apiv1"
	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	"context"
	"errors"
	firebase "firebase.google.com/go"
	"fmt"
	"github.com/rs/zerolog/log"
	"google.golang.org/api/iterator"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
	secretmanagerpb "google.golang.org/genproto/googleapis/cloud/secretmanager/v1"
	"strings"
)

type ClusterCreds struct {
	Username string
	Password string
}

func GetUsernameAndPassword(usernameId, passwordId string) (clusterCreds ClusterCreds, err error) {
	ctx := context.Background()
	client, err := secretmanager.NewClient(ctx)
	if err != nil {
		return
	}
	defer client.Close()

	res, err := client.AccessSecretVersion(ctx, &secretmanagerpb.AccessSecretVersionRequest{Name: usernameId})
	if err != nil {
		return
	}
	clusterCreds.Username = string(res.Payload.Data)
	res, err = client.AccessSecretVersion(ctx, &secretmanagerpb.AccessSecretVersionRequest{Name: passwordId})
	if err != nil {
		return
	}
	clusterCreds.Password = string(res.Payload.Data)
	return
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

func generateInstanceNamesFilter(instanceNames []string) (namesFilter string) {
	if len(instanceNames) == 0 {
		log.Fatal().Err(errors.New("no instances found in instance group"))
		return
	}

	namesFilter = fmt.Sprintf("name=%s", instanceNames[0])
	for _, instanceName := range instanceNames[1:] {
		namesFilter = fmt.Sprintf("%s OR name=%s", namesFilter, instanceName)
	}
	log.Info().Msgf("%s", namesFilter)
	return
}

func GetInstances(project, zone string, instanceNames []string) (instances []*computepb.Instance, err error) {
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
			log.Fatal().Err(err)
			break
		}
		log.Info().Msgf("%s %d %s", *resp.Name, resp.Id, *resp.NetworkInterfaces[0].NetworkIP)
		instances = append(instances, resp)

		_ = resp
	}
	return
}

func GetInstanceGroupInstanceNames(project, zone, instanceGroup string) (instanceNames []string) {
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
			log.Fatal().Err(err)
			break
		}
		split := strings.Split(resp.GetInstance(), "/")
		instanceNames = append(instanceNames, split[len(split)-1])
		log.Info().Msgf("%s", split[len(split)-1])
	}
	return
}
