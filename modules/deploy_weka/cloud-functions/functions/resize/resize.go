package resize

import (
	"cloud.google.com/go/storage"
	"context"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"time"
)

func UpdateValue(bucket string, newDesiredSize int) (err error) {
	ctx := context.Background()
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

	err = updateDesiredSize(client, ctx, bucket, newDesiredSize)
	err = common.Unlock(client, ctx, bucket, id) // we always want to unlock

	return
}

func updateDesiredSize(client *storage.Client, ctx context.Context, bucket string, desiredSize int) (err error) {
	stateHandler := client.Bucket(bucket).Object("state")

	state, err := common.ReadState(stateHandler, ctx)
	if err != nil {
		return
	}

	state.DesiredSize = desiredSize
	err = common.WriteState(stateHandler, ctx, state)
	return
}
