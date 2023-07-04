package report

import (
	"context"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/go-cloud-lib/protocol"
	reportLib "github.com/weka/go-cloud-lib/report"
)

func Report(ctx context.Context, report protocol.Report, bucket string) (err error) {
	log.Info().Msgf("Updating state %s with %s", report.Type, report.Message)
	state, err := common.GetClusterState(ctx, bucket)
	if err != nil {
		return
	}
	err = reportLib.UpdateReport(report, &state)
	if err != nil {
		return
	}
	err = common.UpdateClusterState(ctx, bucket, state)
	return
}
