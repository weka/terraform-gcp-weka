package status

import (
	"context"
	"encoding/json"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/weka_api"
	cloudLibCommon "github.com/weka/go-cloud-lib/common"
	"github.com/weka/go-cloud-lib/lib/weka"
	"github.com/weka/go-cloud-lib/logging"

	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/go-cloud-lib/protocol"
)

func GetReports(ctx context.Context, project, zone, bucket, object, instanceGroup string) (reports protocol.Reports, err error) {
	logger := logging.LoggerFromCtx(ctx)
	logger.Info().Msg("fetching cluster status...")

	state, err := common.GetClusterState(ctx, bucket, object)
	if err != nil {
		return
	}
	reports.ReadyForClusterization = common.GetInstancesNames(state.Instances)
	reports.Progress = state.Progress
	reports.Errors = state.Errors

	clusterizationInstance := ""
	if len(state.Instances) >= state.ClusterizationTarget && state.ClusterizationTarget > 0 {
		clusterizationInstance = state.Instances[state.ClusterizationTarget-1].Name
	}

	progressInstancesNames := make([]string, 0, len(state.Progress))
	for instance := range state.Progress {
		progressInstancesNames = append(progressInstancesNames, instance)
	}

	var inProgress []string

	if !state.Clusterized {
		aliveInProgressInstances, err := common.GetInstances(ctx, project, zone, progressInstancesNames)
		if err != nil {
			return reports, err
		}

		for _, instance := range aliveInProgressInstances {
			if !cloudLibCommon.IsItemInList(*instance.Name, reports.ReadyForClusterization) {
				inProgress = append(inProgress, *instance.Name)
			}
		}
	}

	reports.InProgress = inProgress

	summary := protocol.ClusterizationStatusSummary{
		ReadyForClusterization: len(state.Instances),
		InProgress:             len(inProgress),
		ClusterizationInstance: clusterizationInstance,
		ClusterizationTarget:   state.ClusterizationTarget,
		Clusterized:            state.Clusterized,
	}

	reports.Summary = summary
	return
}

func GetClusterStatus(ctx context.Context, bucket, object string) (clusterStatus protocol.ClusterStatus, err error) {
	state, err := common.GetClusterState(ctx, bucket, object)
	if err != nil {
		return
	}
	clusterStatus.InitialSize = state.InitialSize
	clusterStatus.DesiredSize = state.DesiredSize
	clusterStatus.Clusterized = state.Clusterized

	if !state.Clusterized {
		return
	}

	wekaApi := weka_api.WekaApiRequest{
		Method: weka.JrpcStatus,
		Params: nil,
	}
	rawWekaStatus, err := weka_api.RunWekaApi(ctx, &wekaApi)
	if err != nil {
		return
	}

	wekaStatus := protocol.WekaStatus{}
	if err = json.Unmarshal(rawWekaStatus, &wekaStatus); err != nil {
		return
	}
	clusterStatus.WekaStatus = wekaStatus

	return
}
