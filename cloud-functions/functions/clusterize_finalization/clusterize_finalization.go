package clusterize_finalization

import (
	"context"

	"cloud.google.com/go/storage"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/go-cloud-lib/protocol"
)

func ClusterizeFinalization(ctx context.Context, project, zone, instanceGroup, bucket string) (err error) {
	log.Info().Msg("Finalizing clusterization")

	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Error().Err(err).Msg("Failed creating storage client")
		return
	}
	defer client.Close()

	id, err := common.LockBucket(ctx, client, bucket)
	defer common.UnlockBucket(ctx, client, bucket, id)

	stateHandler := client.Bucket(bucket).Object("state")
	state, err := common.ReadState(stateHandler, ctx)
	if err != nil {
		return
	}

	instanceNames := common.GetInstancesNames(state.Instances)
	err = common.AddInstancesToGroup(ctx, project, zone, instanceGroup, instanceNames)
	if err != nil {
		return
	}

	state.Instances = []protocol.Vm{}
	state.Clusterized = true
	err = common.RetryWriteState(stateHandler, ctx, state)

	return
}
