package report

import (
	"cloud.google.com/go/storage"
	"context"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/go-cloud-lib/protocol"
	reportLib "github.com/weka/go-cloud-lib/report"
	"time"
)

func Report(ctx context.Context, report protocol.Report, bucket string) (err error) {
	log.Info().Msgf("Updating state %s with %s", report.Type, report.Message)
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

	stateHandler := client.Bucket(bucket).Object("state")

	state, err := common.ReadState(stateHandler, ctx)
	if err != nil {
		return
	}

	err = reportLib.UpdateReport(report, &state)
	if err != nil {
		return
	}

	err = common.WriteState(stateHandler, ctx, state)

	err = common.Unlock(client, ctx, bucket, id)
	return
}
