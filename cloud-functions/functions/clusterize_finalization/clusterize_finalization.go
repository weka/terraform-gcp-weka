package clusterize_finalization

import (
	"context"
	"fmt"

	"cloud.google.com/go/storage"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/go-cloud-lib/protocol"
)

func ClusterizeFinalization(ctx context.Context, project, zone, instanceGroup, bucket, object string, protocolGw protocol.ProtocolGW) (err error) {
	log.Info().Msg("Finalizing clusterization")

	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Error().Err(err).Msg("Failed creating storage client")
		return
	}
	defer client.Close()

	id, err := common.LockBucket(ctx, client, bucket, object)
	defer common.UnlockBucket(ctx, client, bucket, object, id)

	stateHandler := client.Bucket(bucket).Object(object)
	state, err := common.ReadState(stateHandler, ctx)
	if err != nil {
		return
	}

	instanceNames := common.GetInstancesNames(state.Instances)

	if protocolGw == protocol.NFS {
		// Add tag to all clusterized NFS instances
		labels := map[string]string{
			common.NfsInterfaceGroupPortKey: common.NfsInterfaceGroupPortValue,
		}
		log.Info().Msgf("Adding label %s to %d NFS instances %v", common.NfsInterfaceGroupPortKey, len(instanceNames), instanceNames)

		for _, instanceName := range instanceNames {
			err = common.AddLabelsOnInstance(ctx, project, zone, instanceName, labels)
			if err != nil {
				err = fmt.Errorf("cannot add label %s to instance %s: %w", common.NfsInterfaceGroupPortKey, instanceName, err)
				common.ReportMsg(ctx, instanceName, bucket, object, "error", err.Error())
				continue
			}
		}
	}

	err = common.AddInstancesToGroup(ctx, project, zone, instanceGroup, instanceNames)
	if err != nil {
		return
	}

	state.Instances = []protocol.Vm{}
	state.Clusterized = true
	err = common.RetryWriteState(stateHandler, ctx, state)

	return
}
