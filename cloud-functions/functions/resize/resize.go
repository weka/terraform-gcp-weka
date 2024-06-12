package resize

import (
	"context"
	"errors"

	"cloud.google.com/go/storage"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
)

func UpdateValue(ctx context.Context, bucket string, newDesiredSize int) (err error) {
	log.Debug().Msgf("Updating desired size to %d", newDesiredSize)

	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Error().Err(err).Msg("Failed creating storage client")
		return
	}
	defer client.Close()

	id, err := common.LockBucket(ctx, client, bucket)
	defer common.UnlockBucket(ctx, client, bucket, id)

	err = updateDesiredSize(client, ctx, bucket, newDesiredSize)
	return
}

func updateDesiredSize(client *storage.Client, ctx context.Context, bucket string, desiredSize int) (err error) {
	stateHandler := client.Bucket(bucket).Object("state")
	state, err := common.ReadState(stateHandler, ctx)
	if err != nil {
		return
	}

	if !state.Clusterized {
		err = errors.New("weka cluster is not ready")
		return
	}

	state.DesiredSize = desiredSize
	err = common.RetryWriteState(stateHandler, ctx, state)
	return
}
