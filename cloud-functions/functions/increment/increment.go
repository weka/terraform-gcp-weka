package increment

import (
	"cloud.google.com/go/storage"
	"context"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/cloud-functions/common"
	"time"
)

func Add(bucket, newInstance string) (err error) {
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

	err = addInstance(client, ctx, bucket, newInstance)
	err = common.Unlock(client, ctx, bucket, id) // we always want to unlock

	return
}

func addInstance(client *storage.Client, ctx context.Context, bucket, newInstance string) (err error) {
	stateHandler := client.Bucket(bucket).Object("state")

	state, err := common.ReadState(stateHandler, ctx)
	if err != nil {
		return
	}
	state.Instances = append(state.Instances, newInstance)

	err = common.WriteState(stateHandler, ctx, state)
	return
}
