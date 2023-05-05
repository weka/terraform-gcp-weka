package terminate_cluster

import (
	"context"

	"cloud.google.com/go/storage"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
)

func DeleteStateObject(ctx context.Context, bucket string) (err error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Error().Msgf("Failed creating storage client: %s", err)
		return
	}
	defer client.Close()

	stateHandler := client.Bucket(bucket).Object("state")
	return stateHandler.Delete(ctx)
}

func TerminateInstances(ctx context.Context, project, zone, clusterName string) (terminatingInstances []string, errs []error) {
	instances := common.GetInstancesByClusterLabel(ctx, project, zone, clusterName)
	var instanceNames []string
	var instanceName string
	var err error
	for _, instance := range instances {
		instanceName = *instance.Name
		err = common.UnsetDeletionProtection(ctx, project, zone, instanceName)
		if err != nil {
			errs = append(errs, err)
			continue
		}
		instanceNames = append(instanceNames, instanceName)
	}
	terminatingInstances, errs2 := common.TerminateInstances(ctx, project, zone, instanceNames)
	errs = append(errs, errs2...)
	return
}
