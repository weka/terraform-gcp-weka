package resize

import (
	"context"
	"errors"
	"time"

	"cloud.google.com/go/storage"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
)

func UpdateValue(ctx context.Context, bucket string, newDesiredSize int) (err error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		log.Error().Msgf("Failed creating storage client: %s", err)
		return
	}
	defer client.Close()

	id, err := common.Lock(client, ctx, bucket)
	for err != nil {
		time.Sleep(1 * time.Second)
		id, err = common.Lock(client, ctx, bucket)
	}
	defer common.Unlock(client, ctx, bucket, id)

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
	err = common.WriteState(stateHandler, ctx, state)
	return
}
