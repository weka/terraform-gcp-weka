package common

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"time"

	compute "cloud.google.com/go/compute/apiv1"
	"cloud.google.com/go/compute/apiv1/computepb"
	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	"cloud.google.com/go/secretmanager/apiv1/secretmanagerpb"
	"cloud.google.com/go/storage"
	"github.com/googleapis/gax-go/v2"
	"github.com/rs/zerolog/log"
	"google.golang.org/api/iterator"

	"github.com/weka/go-cloud-lib/protocol"
	reportLib "github.com/weka/go-cloud-lib/report"
)

func GetUsernameAndPassword(ctx context.Context, usernameId, passwordId string) (clusterCreds protocol.ClusterCreds, err error) {
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
	namesFilter = fmt.Sprintf("name=%s", instanceNames[0])
	for _, instanceName := range instanceNames[1:] {
		namesFilter = fmt.Sprintf("%s OR name=%s", namesFilter, instanceName)
	}
	log.Info().Msgf("%s", namesFilter)
	return
}

func GetInstances(ctx context.Context, project, zone string, instanceNames []string) (instances []*computepb.Instance, err error) {
	if len(instanceNames) == 0 {
		log.Warn().Msg("Got empty instance names list")
		return
	}

	namesFilter := generateInstanceNamesFilter(instanceNames)

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

func GetInstanceGroupInstanceNames(ctx context.Context, project, zone, instanceGroup string) (instanceNames []string) {
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
	lockHandler := client.Bucket(bucket).Object("lock")

	w := lockHandler.If(storage.Conditions{DoesNotExist: true}).NewWriter(ctx)

	err = func() error {
		if _, err := w.Write([]byte("locked")); err != nil {
			log.Error().Msgf("write failed: %s", err)
		}
		return w.Close()
	}()

	if err != nil {
		log.Debug().Err(err).Msg("lock failed")

		attrs, attrsErr := lockHandler.Attrs(ctx)
		if attrsErr != nil {
			log.Error().Err(attrsErr).Msg("Failed to get lock attributes")
			err = fmt.Errorf("%w; %w", err, attrsErr)
			return
		}

		if time.Since(attrs.Created) > time.Minute*10 {
			log.Error().Msgf("Deleting lock, we have indication that unlock failed at some point")
			deleteLockErr := lockHandler.Delete(ctx)
			if deleteLockErr != nil {
				log.Error().Err(deleteLockErr).Msg("Failed to delete lock")
				err = fmt.Errorf("%w; %w", err, deleteLockErr)
				return
			}
		}
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

func ReadState(stateHandler *storage.ObjectHandle, ctx context.Context) (state protocol.ClusterState, err error) {
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

func RetryWriteState(stateHandler *storage.ObjectHandle, ctx context.Context, state protocol.ClusterState) (err error) {
	// See https://cloud.google.com/storage/docs/samples/storage-configure-retries#storage_configure_retries-go
	stateHandler = stateHandler.Retryer(
		storage.WithBackoff(gax.Backoff{
			Initial:    700 * time.Millisecond,
			Max:        10 * time.Second, // maximum retry delay
			Multiplier: 1.5,              // backoff multiplier
		}),
		storage.WithPolicy(storage.RetryAlways), // all requests are retried
	)

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
		// Possible error (rate limit exceeded):
		// Failed closing object writer: googleapi: Error 429: The object <path-to-obj> exceeded the rate limit for object mutation operations (create, update, and delete). Please reduce your request rate. See https://cloud.google.com/storage/docs/gcs429., rateLimitExceeded
		log.Error().Msgf("Failed closing object writer: %s", err)
	}
	return
}

func GetClusterState(ctx context.Context, bucket string) (state protocol.ClusterState, err error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Error().Err(err).Msg("Failed creating storage client")
		return
	}
	defer client.Close()

	id, err := Lock(client, ctx, bucket)
	for err != nil {
		time.Sleep(1 * time.Second)
		id, err = Lock(client, ctx, bucket)
	}
	defer Unlock(client, ctx, bucket, id)

	stateHandler := client.Bucket(bucket).Object("state")
	state, err = ReadState(stateHandler, ctx)
	return
}

func LockBucket(ctx context.Context, client *storage.Client, bucket string) (id string, err error) {
	id, err = Lock(client, ctx, bucket)
	for err != nil {
		log.Debug().Str("bucket", bucket).Msgf("Failed locking bucket, retrying")

		time.Sleep(1 * time.Second)
		id, err = Lock(client, ctx, bucket)
	}
	return
}

func UnlockBucket(ctx context.Context, client *storage.Client, bucket, id string) (err error) {
	err = Unlock(client, ctx, bucket, id)
	if err != nil {
		log.Error().Err(err).Str("bucket", bucket).Msg("Failed unlocking bucket")
	}
	return
}

func GetInstancesByClusterLabel(ctx context.Context, project, zone, clusterName string) (instances []*computepb.Instance) {
	instanceClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}
	defer instanceClient.Close()

	clusterNameFilter := fmt.Sprintf("labels.weka_cluster_name=%s", clusterName)
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

func addInstanceToStateInstances(client *storage.Client, ctx context.Context, bucket string, newInstance protocol.Vm) (state protocol.ClusterState, err error) {
	stateHandler := client.Bucket(bucket).Object("state")

	state, err = ReadState(stateHandler, ctx)
	if err != nil {
		return
	}
	if len(state.Instances) == state.InitialSize {
		//This might happen if someone increases the desired number before the clusterization id done
		err = fmt.Errorf("number of instances is already the initial size, not adding instance %s to state instances list", newInstance)
		log.Error().Msgf("%s", err)
		return
	}
	state.Instances = append(state.Instances, newInstance)

	err = RetryWriteState(stateHandler, ctx, state)
	return
}

func AddInstanceToStateInstances(ctx context.Context, bucket string, newInstance protocol.Vm) (state protocol.ClusterState, err error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Error().Err(err).Msg("Failed creating storage client")
		return
	}
	defer client.Close()

	id, err := LockBucket(ctx, client, bucket)
	defer UnlockBucket(ctx, client, bucket, id)

	state, err = addInstanceToStateInstances(client, ctx, bucket, newInstance)
	return
}

func UpdateStateReporting(ctx context.Context, bucket string, report protocol.Report) (err error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Error().Err(err).Msg("Failed creating storage client")
		return
	}
	defer client.Close()

	id, err := LockBucket(ctx, client, bucket)
	defer UnlockBucket(ctx, client, bucket, id)

	stateHandler := client.Bucket(bucket).Object("state")
	state, err := ReadState(stateHandler, ctx)

	err = reportLib.UpdateReport(report, &state)
	if err != nil {
		err = fmt.Errorf("failed updating state report")
		return
	}
	err = RetryWriteState(stateHandler, ctx, state)
	return
}

func ReportMsg(ctx context.Context, hostName, bucket, reportType, message string) {
	reportObj := protocol.Report{Type: reportType, Hostname: hostName, Message: message}
	_ = UpdateStateReporting(ctx, bucket, reportObj)
}

func GetInstancesNames(instances []protocol.Vm) (vmNames []string) {
	for _, instance := range instances {
		vmNames = append(vmNames, instance.Name)
	}
	return
}

func SetDeletionProtection(ctx context.Context, project, zone, bucket, instanceName string) (err error) {
	log.Info().Msgf("Setting deletion protection on %s", instanceName)

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

	msg := "Deletion protection was set successfully"
	log.Info().Msg(msg)
	ReportMsg(ctx, instanceName, bucket, "progress", msg)

	return
}

func AddInstancesToGroup(ctx context.Context, project, zone, instanceGroup string, instancesNames []string) (err error) {
	log.Info().Msgf("Adding instances: %s to instance group %s", instancesNames, instanceGroup)

	instances, err := GetInstances(ctx, project, zone, instancesNames)
	if err != nil {
		return
	}
	var instanceReferences []*computepb.InstanceReference
	for _, instance := range instances {
		instanceReferences = append(instanceReferences, &computepb.InstanceReference{Instance: instance.SelfLink})
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
			Instances: instanceReferences,
		},
		Project: project,
		Zone:    zone,
	})

	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}

	log.Info().Msgf("Instances: %s, were added to instance group successfully", instancesNames)
	return
}

func UnsetDeletionProtection(ctx context.Context, project, zone, instanceName string) (err error) {
	log.Info().Msgf("Removing deletion protection on %s", instanceName)

	c, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}
	defer c.Close()

	value := false
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

	log.Info().Msgf("Removed deletion protection on %s", instanceName)
	return
}

func TerminateInstances(ctx context.Context, project, zone string, instanceNames []string) (terminatingInstances []string, errs []error) {
	instanceClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Fatal().Err(err)
		errs = append(errs, err)
		return
	}
	defer instanceClient.Close()

	log.Info().Msgf("Terminating instances %s", instanceNames)
	for _, instanceName := range instanceNames {
		_, err := instanceClient.Delete(ctx, &computepb.DeleteInstanceRequest{
			Project:  project,
			Zone:     zone,
			Instance: instanceName,
		})
		if err != nil {
			log.Error().Msgf("error terminating instances %s", err.Error())
			errs = append(errs, err)
			continue
		}
		terminatingInstances = append(terminatingInstances, instanceName)
	}
	return
}

func GetInstanceGroupBackendsIps(instances []*computepb.Instance) (instanceGroupBackendsIps []string) {
	for _, instance := range instances {
		instanceGroupBackendsIps = append(instanceGroupBackendsIps, *instance.NetworkInterfaces[0].NetworkIP)
	}
	return
}

func GetBackendsIps(ctx context.Context, project, zone string, instancesNames []string) (backendsIps []string) {
	instances, err := GetInstances(ctx, project, zone, instancesNames)
	if err != nil {
		return
	}
	for _, instance := range instances {
		// get one IP per instance
		backendsIps = append(backendsIps, *instance.NetworkInterfaces[0].NetworkIP)
	}
	return
}

func CreateBucket(ctx context.Context, project, region, obsName string) (err error) {
	log.Info().Msgf("Creating bucket %s", obsName)
	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	attrs := &storage.BucketAttrs{
		Location: region,
	}
	// Creates a Bucket instance.
	if err = client.Bucket(obsName).Create(ctx, project, attrs); err != nil {
		log.Error().Err(err).Send()
		return
	}
	return
}

const FindDrivesScript = `
import json
import sys
for d in json.load(sys.stdin)['disks']:
	if d['isRotational']: continue
	if d['type'] != 'DISK': continue
	if d['isMounted']: continue
	if d['model'] != 'nvme_card': continue
	print(d['devPath'])
`
