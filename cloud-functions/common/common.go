package common

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"math/rand"
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

	"github.com/weka/go-cloud-lib/connectors"
	"github.com/weka/go-cloud-lib/lib/jrpc"
	"github.com/weka/go-cloud-lib/lib/weka"
	"github.com/weka/go-cloud-lib/protocol"
	reportLib "github.com/weka/go-cloud-lib/report"
)

const (
	AdminUsername = "admin"

	WekaClusterLabelKey    = "weka_cluster_name"
	WekaProtocolGwLabelKey = "weka_protocol_gateway"

	NfsInterfaceGroupPortKey   = "nfs_interface_group_port"
	NfsInterfaceGroupPortValue = "ready"
)

func GetDeploymentOrAdminUsernameAndPassword(ctx context.Context, project, usernameId, passwordId, adminPasswordId string) (clusterCreds protocol.ClusterCreds, err error) {
	log.Info().Msgf("Fetching username %s and password %s", usernameId, passwordId)
	client, err := secretmanager.NewClient(ctx)
	if err != nil {
		return
	}
	defer client.Close()

	deploymentPassword, err := getLatestSecretVersion(ctx, client, passwordId)
	// if deploymentPassword doesn't exist, try to get adminPassword
	if err != nil && (strings.Contains(err.Error(), "NOT_FOUND") || strings.Contains(err.Error(), "NotFound")) {
		adminPassword, err := getLatestSecretVersion(ctx, client, adminPasswordId)
		if err != nil {
			log.Error().Err(err).Send()
			return clusterCreds, err
		}
		clusterCreds.Password = adminPassword
		clusterCreds.Username = AdminUsername
		return clusterCreds, nil
	}
	if err != nil {
		log.Error().Err(err).Send()
		return clusterCreds, err
	}

	clusterCreds.Password = deploymentPassword
	clusterCreds.Username, err = getLatestSecretVersion(ctx, client, usernameId)
	if err != nil {
		log.Error().Err(err).Send()
	}
	return
}

func GetWekaAdminCredentials(ctx context.Context, project, adminPasswordId string) (clusterCreds protocol.ClusterCreds, err error) {
	log.Info().Msgf("Fetching admin password %s", adminPasswordId)
	client, err := secretmanager.NewClient(ctx)
	if err != nil {
		return
	}
	defer client.Close()

	adminPassword, err := getLatestSecretVersion(ctx, client, adminPasswordId)
	if err != nil {
		log.Error().Err(err).Send()
		return clusterCreds, err
	}
	clusterCreds.Password = adminPassword
	clusterCreds.Username = AdminUsername
	return
}

func GetWekaDeploymentCredentials(ctx context.Context, project, usernameId, passwordId string) (clusterCreds protocol.ClusterCreds, err error) {
	log.Info().Msgf("Fetching weka deployment username %s and password %s", usernameId, passwordId)
	client, err := secretmanager.NewClient(ctx)
	if err != nil {
		return
	}
	defer client.Close()

	deploymentPassword, err := getLatestSecretVersion(ctx, client, passwordId)
	if err != nil {
		log.Error().Err(err).Send()
		return clusterCreds, err
	}

	username, err := getLatestSecretVersion(ctx, client, usernameId)
	if err != nil {
		log.Error().Err(err).Send()
		return clusterCreds, err
	}

	clusterCreds.Password = deploymentPassword
	clusterCreds.Username = username
	return
}

func getLatestSecretVersion(ctx context.Context, client *secretmanager.Client, secretId string) (secret string, err error) {
	req := &secretmanagerpb.AccessSecretVersionRequest{
		Name: fmt.Sprintf("%s/versions/latest", secretId),
	}
	secretVersion, err := client.AccessSecretVersion(ctx, req)
	if err != nil {
		err = fmt.Errorf("failed accessing secret version (%s): %w", secretId, err)
		return
	}
	secret = string(secretVersion.Payload.Data)
	return
}

func GetSecret(ctx context.Context, secretId string) (secret string, err error) {
	client, err := secretmanager.NewClient(ctx)
	if err != nil {
		return
	}
	defer client.Close()

	return getLatestSecretVersion(ctx, client, secretId)
}

func SetSecretVersion(ctx context.Context, secretId, secret string) (err error) {
	client, err := secretmanager.NewClient(ctx)
	if err != nil {
		return
	}
	defer client.Close()

	_, err = client.AddSecretVersion(ctx, &secretmanagerpb.AddSecretVersionRequest{
		Parent: secretId,
		Payload: &secretmanagerpb.SecretPayload{
			Data: []byte(secret),
		},
	})
	if err != nil {
		err = fmt.Errorf("failed adding secret version: %w", err)
	}
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

func Lock(client *storage.Client, ctx context.Context, bucket, object string) (id string, err error) {
	objLockName := fmt.Sprintf("%s.lock", object)
	lockHandler := client.Bucket(bucket).Object(objLockName)

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

func Unlock(client *storage.Client, ctx context.Context, bucket, object, id string) (err error) {
	objLockName := fmt.Sprintf("%s.lock", object)
	gen, err := strconv.ParseInt(id, 10, 64)
	if err != nil {
		log.Error().Msgf("Lock ID should be numerical value, got '%s'", id)
		return
	}
	LockHandler := client.Bucket(bucket).Object(objLockName)
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

func GetClusterState(ctx context.Context, bucket, object string) (state protocol.ClusterState, err error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Error().Err(err).Msg("Failed creating storage client")
		return
	}
	defer client.Close()

	id, err := LockBucket(ctx, client, bucket, object)
	defer UnlockBucket(ctx, client, bucket, object, id)

	stateHandler := client.Bucket(bucket).Object(object)
	state, err = ReadState(stateHandler, ctx)
	return
}

func LockBucket(ctx context.Context, client *storage.Client, bucket, object string) (id string, err error) {
	id, err = Lock(client, ctx, bucket, object)
	for err != nil {
		log.Debug().Str("bucket", bucket).Str("object", object).Msgf("Failed locking storage object, retrying")

		time.Sleep(1 * time.Second)
		id, err = Lock(client, ctx, bucket, object)
	}
	return
}

func UnlockBucket(ctx context.Context, client *storage.Client, bucket, object, id string) (err error) {
	err = Unlock(client, ctx, bucket, object, id)
	if err != nil {
		log.Error().Err(err).Str("bucket", bucket).Str("object", object).Msg("Failed unlocking storage object")
	}
	return
}

func GetWekaJrpcPool(ctx context.Context, project, zone, instanceGroup, usernameId, passwordId, adminPasswordId string) (jpool *jrpc.Pool, err error) {
	creds, err := GetDeploymentOrAdminUsernameAndPassword(ctx, project, usernameId, passwordId, adminPasswordId)
	if err != nil {
		return
	}

	jrpcBuilder := func(ip string) *jrpc.BaseClient {
		return connectors.NewJrpcClient(ctx, ip, weka.ManagementJrpcPort, creds.Username, creds.Password)
	}

	instances, err := GetInstances(ctx, project, zone, GetInstanceGroupInstanceNames(ctx, project, zone, instanceGroup))
	if err != nil {
		return
	}

	ips := GetInstanceGroupBackendsIps(instances)
	r := rand.New(rand.NewSource(time.Now().UnixNano()))
	r.Shuffle(len(ips), func(i, j int) { ips[i], ips[j] = ips[j], ips[i] })
	jpool = &jrpc.Pool{
		Ips:     ips,
		Clients: map[string]*jrpc.BaseClient{},
		Active:  "",
		Builder: jrpcBuilder,
		Ctx:     ctx,
	}
	return
}

func GetInstancesByLabel(ctx context.Context, project, zone, labelKey, labelValue string) (instances []*computepb.Instance, err error) {
	instanceClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}
	defer instanceClient.Close()

	labelFilter := fmt.Sprintf("labels.%s=%s", labelKey, labelValue)
	listInstanceRequest := &computepb.ListInstancesRequest{
		Project: project,
		Zone:    zone,
		Filter:  &labelFilter,
	}

	listInstanceIter := instanceClient.List(ctx, listInstanceRequest)

	for {
		resp, err2 := listInstanceIter.Next()
		if errors.Is(err2, iterator.Done) {
			break
		}
		if err2 != nil {
			err = fmt.Errorf("error getting next instances by label: %w", err2)
			log.Error().Err(err).Send()
			break
		}
		instances = append(instances, resp)
	}
	log.Debug().Msgf("Found %d instances with label %s=%s", len(instances), labelKey, labelValue)
	return
}

func GetInstancesByClusterLabel(ctx context.Context, project, zone, clusterName string) ([]*computepb.Instance, error) {
	return GetInstancesByLabel(ctx, project, zone, WekaClusterLabelKey, clusterName)
}

func GetInstancesByProtocolGwLabel(ctx context.Context, project, zone, gatewaysName string) ([]*computepb.Instance, error) {
	return GetInstancesByLabel(ctx, project, zone, WekaProtocolGwLabelKey, gatewaysName)
}

func addInstanceToStateInstances(client *storage.Client, ctx context.Context, bucket, object string, newInstance protocol.Vm) (state protocol.ClusterState, err error) {
	stateHandler := client.Bucket(bucket).Object(object)

	state, err = ReadState(stateHandler, ctx)
	if err != nil {
		return
	}
	if state.Clusterized {
		err = NewExtraInstanceForClusterizationError(newInstance.Name)
		log.Error().Msgf("cluster is already clusterized, not adding instance %s to state instances list", newInstance)
		return
	}
	if len(state.Instances) >= state.ClusterizationTarget {
		//This might happen if someone increases the desired number before the clusterization id done
		err = NewExtraInstanceForClusterizationError(newInstance.Name)
		log.Error().Msgf("number of instances is already same as clusterization target, not adding instance %s to state instances list", newInstance)
		return
	}
	state.Instances = append(state.Instances, newInstance)

	err = RetryWriteState(stateHandler, ctx, state)
	return
}

func AddInstanceToStateInstances(ctx context.Context, bucket, object string, newInstance protocol.Vm) (state protocol.ClusterState, err error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Error().Err(err).Msg("Failed creating storage client")
		return
	}
	defer client.Close()

	id, err := LockBucket(ctx, client, bucket, object)
	defer UnlockBucket(ctx, client, bucket, object, id)

	state, err = addInstanceToStateInstances(client, ctx, bucket, object, newInstance)
	return
}

func UpdateStateNfsMigrated(ctx context.Context, bucket, object string) (err error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Error().Err(err).Msg("Failed creating storage client")
		return
	}
	defer client.Close()

	id, err := LockBucket(ctx, client, bucket, object)
	defer UnlockBucket(ctx, client, bucket, object, id)

	stateHandler := client.Bucket(bucket).Object(object)
	state, err := ReadState(stateHandler, ctx)
	if err != nil {
		return
	}
	state.NfsInstancesMigrated = true
	err = RetryWriteState(stateHandler, ctx, state)
	return
}

func UpdateStateReporting(ctx context.Context, bucket, object string, report protocol.Report) (err error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Error().Err(err).Msg("Failed creating storage client")
		return
	}
	defer client.Close()

	id, err := LockBucket(ctx, client, bucket, object)
	defer UnlockBucket(ctx, client, bucket, object, id)

	stateHandler := client.Bucket(bucket).Object(object)
	state, err := ReadState(stateHandler, ctx)

	err = reportLib.UpdateReport(report, &state)
	if err != nil {
		err = fmt.Errorf("failed updating state report")
		return
	}
	err = RetryWriteState(stateHandler, ctx, state)
	return
}

func ReportMsg(ctx context.Context, hostName, bucket, object, reportType, message string) {
	reportObj := protocol.Report{Type: reportType, Hostname: hostName, Message: message}
	_ = UpdateStateReporting(ctx, bucket, object, reportObj)
}

func GetInstancesNames(instances []protocol.Vm) (vmNames []string) {
	for _, instance := range instances {
		vmNames = append(vmNames, instance.Name)
	}
	return
}

func SetDeletionProtection(ctx context.Context, project, zone, bucket, object, instanceName string) (err error) {
	log.Info().Msgf("Setting deletion protection on %s", instanceName)

	c, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Error().Err(err).Send()
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
		ReportMsg(ctx, instanceName, bucket, object, "error", fmt.Sprintf("failed setting deletion protection: %v", err))
		log.Error().Err(err).Send()
		return
	}

	msg := "Deletion protection was set successfully"
	log.Info().Msg(msg)
	ReportMsg(ctx, instanceName, bucket, object, "progress", msg)

	return
}

func AddLabelsOnInstance(ctx context.Context, project, zone, instanceName string, labels map[string]string) (err error) {
	log.Info().Msgf("Adding labels: %v to instance %s", labels, instanceName)

	c, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	// get instance to get old labels fingerprint
	instance, err := c.Get(ctx, &computepb.GetInstanceRequest{
		Project:  project,
		Zone:     zone,
		Instance: instanceName,
	})
	if err != nil {
		err = fmt.Errorf("error getting instance: %w", err)
		log.Error().Err(err).Send()
		return
	}

	newLabels := make(map[string]string)
	for k, v := range instance.Labels {
		newLabels[k] = v
	}
	for k, v := range labels {
		newLabels[k] = v
	}

	req := &computepb.SetLabelsInstanceRequest{
		Project:  project,
		Zone:     zone,
		Instance: instanceName,
		InstancesSetLabelsRequestResource: &computepb.InstancesSetLabelsRequest{
			Labels:           newLabels,
			LabelFingerprint: instance.LabelFingerprint,
		},
	}

	_, err = c.SetLabels(ctx, req)
	if err != nil {
		err = fmt.Errorf("error adding labels to instance: %w", err)
		log.Error().Err(err).Send()
		return
	}

	log.Info().Any("labels", labels).Msg("Labels were added to instance successfully")
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
		log.Error().Err(err).Send()
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
		log.Error().Err(err).Send()
		return
	}

	log.Info().Msgf("Instances: %s, were added to instance group successfully", instancesNames)
	return
}

func UnsetDeletionProtection(ctx context.Context, project, zone, instanceName string) (err error) {
	log.Info().Msgf("Removing deletion protection on %s", instanceName)

	c, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Error().Err(err).Send()
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
		log.Error().Err(err).Send()
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
	if not d['model'].startswith('nvme_card'): continue
	if d['model'] == "nvme_card-pd": continue # to support boot_disk_type = "pd-balanced" (e.g. c3-standard-8-lssd)
	print(d['devPath'])
`
