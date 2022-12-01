package status

import (
	"context"
	"encoding/json"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/connectors"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/lib/jrpc"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/lib/weka"
	"math/rand"
	"time"
)

type ClusterStatus struct {
	InitialSize            int                 `json:"initial_size"`
	DesiredSize            int                 `json:"desired_size"`
	Clusterized            bool                `json:"clusterized"`
	ReadyForClusterization []string            `json:"ready_for_clusterization"`
	SystemStatus           weka.StatusResponse `json:"system_status"`
	RawWekaStatus          json.RawMessage     `json:"raw_weka_status"`
}

func GetClusterStatus(project, zone, bucket, instanceGroup, usernameId, passwordId string) (clusterStatus ClusterStatus, err error) {
	state, err := common.GetClusterState(bucket)
	if err != nil {
		return
	}
	clusterStatus.InitialSize = state.InitialSize
	clusterStatus.DesiredSize = state.DesiredSize
	clusterStatus.Clusterized = state.Clusterized
	clusterStatus.ReadyForClusterization = state.Instances
	if !state.Clusterized {
		return
	}

	creds, err := common.GetUsernameAndPassword(usernameId, passwordId)
	if err != nil {
		return
	}

	ctx := context.Background()
	jrpcBuilder := func(ip string) *jrpc.BaseClient {
		return connectors.NewJrpcClient(ctx, ip, weka.ManagementJrpcPort, creds.Username, creds.Password)
	}

	instances, err := common.GetInstances(project, zone, common.GetInstanceGroupInstanceNames(project, zone, instanceGroup))
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
	clusterStatus.RawWekaStatus = rawWekaStatus

	systemStatus := weka.StatusResponse{}
	if err = json.Unmarshal(rawWekaStatus, &systemStatus); err != nil {
		return
	}
	clusterStatus.SystemStatus = systemStatus

	return
}
