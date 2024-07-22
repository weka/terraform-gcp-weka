package status

import (
	"context"
	"encoding/json"
	"math/rand"
	"time"

	cloudLibCommon "github.com/weka/go-cloud-lib/common"
	"github.com/weka/go-cloud-lib/logging"

	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/go-cloud-lib/connectors"
	"github.com/weka/go-cloud-lib/lib/jrpc"
	"github.com/weka/go-cloud-lib/lib/weka"
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
	if len(state.Instances) >= state.ClusterizationTarget {
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

func GetClusterStatus(ctx context.Context, project, zone, bucket, object, instanceGroup, usernameId, passwordId, adminPasswordId string) (clusterStatus protocol.ClusterStatus, err error) {
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

	creds, err := common.GetDeploymentOrAdminUsernameAndPassword(ctx, project, usernameId, passwordId, adminPasswordId)
	if err != nil {
		return
	}

	jrpcBuilder := func(ip string) *jrpc.BaseClient {
		return connectors.NewJrpcClient(ctx, ip, weka.ManagementJrpcPort, creds.Username, creds.Password)
	}

	instances, err := common.GetInstances(ctx, project, zone, common.GetInstanceGroupInstanceNames(ctx, project, zone, instanceGroup))
	if err != nil {
		return
	}

	ips := common.GetInstanceGroupBackendsIps(instances)
	rand.Seed(time.Now().UnixNano())
	rand.Shuffle(len(ips), func(i, j int) { ips[i], ips[j] = ips[j], ips[i] })
	jpool := &jrpc.Pool{
		Ips:     ips,
		Clients: map[string]*jrpc.BaseClient{},
		Active:  "",
		Builder: jrpcBuilder,
		Ctx:     ctx,
	}

	var rawWekaStatus json.RawMessage

	err = jpool.Call(weka.JrpcStatus, struct{}{}, &rawWekaStatus)
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
