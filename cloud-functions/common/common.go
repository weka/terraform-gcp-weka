package common

import (
	compute "cloud.google.com/go/compute/apiv1"
	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	"cloud.google.com/go/storage"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"github.com/rs/zerolog/log"
	"google.golang.org/api/iterator"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
	secretmanagerpb "google.golang.org/genproto/googleapis/cloud/secretmanager/v1"
	"strconv"
	"strings"
	"time"
)

type ClusterCreds struct {
	Username string
	Password string
}

type ClusterState struct {
	InitialSize int      `json:"initial_size"`
	DesiredSize int      `json:"desired_size"`
	Instances   []string `json:"instances"`
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

func Lock(client *storage.Client, ctx context.Context, bucket string) (id string, err error) {
	LockHandler := client.Bucket(bucket).Object("lock")

	w := LockHandler.If(storage.Conditions{DoesNotExist: true}).NewWriter(ctx)
	err = func() error {
		if _, err := w.Write([]byte("locked")); err != nil {
			attrs, err := LockHandler.Attrs(ctx)
			if err != nil {
				return err
			}

			if time.Now().Sub(attrs.Created) > time.Minute*10 {
				log.Error().Msgf("Deleting lock, we have indication that unlock failed at some point")
				err = LockHandler.Delete(ctx)
			}
			return err
		}
		return w.Close()
	}()

	if err != nil {
		log.Debug().Msgf("lock failed: %s", err)
		return
	}

	id = strconv.FormatInt(w.Attrs().Generation, 10)
	return
}

func Unlock(client *storage.Client, ctx context.Context, bucket, id string) (err error) {
	gen, err := strconv.ParseInt(id, 10, 64)
	if err != nil {
		log.Error().Msgf("Lock ID should be numerical value, got '%s'", id)
		return
	}
	LockHandler := client.Bucket(bucket).Object("lock")
	if err = LockHandler.If(storage.Conditions{GenerationMatch: gen}).Delete(ctx); err != nil {
		log.Error().Msgf("delete failed: %s", err)
		return
	}

	return
}

func ReadState(stateHandler *storage.ObjectHandle, ctx context.Context) (state ClusterState, err error) {
	reader, err := stateHandler.NewReader(ctx)
	if err != nil {
		log.Error().Msgf("Failed getting object reader: %s", err)
		return
	}
	defer reader.Close()

	if err = json.NewDecoder(reader).Decode(&state); err != nil {
		log.Error().Msgf("Failed decoding cluster state: %s", err)
		return
	}

	return
}

func WriteState(stateHandler *storage.ObjectHandle, ctx context.Context, state ClusterState) (err error) {
	writer := stateHandler.NewWriter(ctx)
	writer.ContentType = "application/json"

	b, err := json.Marshal(&state)
	if err != nil {
		log.Error().Msgf("Marshaling failed: %s", err)
		return
	}
	_, err = writer.Write(b)
	if err != nil {
		log.Error().Msgf("Failed writing object: %s", err)
		return
	}
	err = writer.Close()
	if err != nil {
		log.Error().Msgf("Failed closing object writer: %s", err)
	}
	return
}

func GetClusterState(bucket string) (state ClusterState, err error) {
	ctx := context.Background()
	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Error().Msgf("Failed creating storage client: %s", err)
		return
	}
	defer client.Close()

	id, err := Lock(client, ctx, bucket)
	for err != nil {
		time.Sleep(1 * time.Second)
		id, err = Lock(client, ctx, bucket)
	}

	stateHandler := client.Bucket(bucket).Object("state")

	state, err = ReadState(stateHandler, ctx)
	err = Unlock(client, ctx, bucket, id)

	return
}

func GetInstancesByClusterLabel(project, zone, clusterName string) (instances []*computepb.Instance) {
	ctx := context.Background()
	instanceClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
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
		instances = append(instances, resp)
	}
	return
}
