package report

import (
	"context"

	"cloud.google.com/go/storage"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/go-cloud-lib/protocol"
	reportLib "github.com/weka/go-cloud-lib/report"
)

func Report(ctx context.Context, report protocol.Report, bucket, object string) (err error) {
	log.Debug().Msgf("Updating %s %s with %s", object, report.Type, report.Message)

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

	err = reportLib.UpdateReport(report, &state)
	if err != nil {
		return
	}

	err = common.RetryWriteState(stateHandler, ctx, state)
	return
}
