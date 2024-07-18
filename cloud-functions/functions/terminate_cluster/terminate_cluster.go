package terminate_cluster

import (
	"context"

	"cloud.google.com/go/storage"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
)

func DeleteStateObject(ctx context.Context, bucket, object string) (err error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Error().Err(err).Msg("Failed creating storage client")
		return
	}
	defer client.Close()

	stateHandler := client.Bucket(bucket).Object(object)
	return stateHandler.Delete(ctx)
}

func TerminateInstances(ctx context.Context, project, zone, labelKey, labelValue string) (terminatingInstances []string, errs []error) {
	instances, err := common.GetInstancesByLabel(ctx, project, zone, labelKey, labelValue)
	if err != nil {
		errs = append(errs, err)
		return
	}
	var instanceNames []string
	var instanceName string
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
