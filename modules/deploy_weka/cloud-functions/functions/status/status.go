package status

import (
	"context"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/connectors"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/lib/jrpc"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/lib/weka"
)

type Status struct {
	InitialSize            int               `json:"initial_size"`
	DesiredSize            int               `json:"desired_size"`
	Clusterized            bool              `json:"clusterized"`
	InstancesCreating      int               `json:"instances_creating"`
	InstanceGroupInstances int               `json:"instance_group_instances"`
	State                  map[string]int    `json:"state"`
	Status                 map[string]int    `json:"status"`
	ProtectionState        []weka.Protection `json:"protectionState"`
}

func Contains(items []string, item string) bool {
	for _, listItem := range items {
		if item == listItem {
			return true
		}
	}
	return false
}

func GetStatus(project, zone, bucket, clusterName, instanceGroup, usernameId, passwordId string) (status Status, err error) {
	state, err := common.GetClusterState(bucket)
	if err != nil {
		return
	}

	status.InitialSize = state.InitialSize
	status.DesiredSize = state.DesiredSize
	status.Clusterized = state.Clusterized

	creds, err := common.GetUsernameAndPassword(usernameId, passwordId)
	if err != nil {
		return
	}

	allInstances := common.GetInstancesByClusterLabel(project, zone, clusterName)
	instanceGroupInstances := common.GetInstanceGroupInstanceNames(project, zone, instanceGroup)
	status.InstancesCreating = len(allInstances) - len(instanceGroupInstances)
	status.InstanceGroupInstances = len(instanceGroupInstances)

	instances, err := common.GetInstances(project, zone, instanceGroupInstances)
	if err != nil {
		return
	}

	ips := common.GetInstanceGroupBackendsIps(instances)
	log.Info().Msgf("Backend ips: %s", ips)

	ctx := context.Background()
	jrpcBuilder := func(ip string) *jrpc.BaseClient {
		return connectors.NewJrpcClient(ctx, ip, weka.ManagementJrpcPort, creds.Username, creds.Password)
	}
	jpool := &jrpc.Pool{
		Ips:     ips,
		Clients: map[string]*jrpc.BaseClient{},
		Active:  "",
		Builder: jrpcBuilder,
		Ctx:     ctx,
	}

	hostsApiList := weka.HostListResponse{}
	err = jpool.Call(weka.JrpcHostList, struct{}{}, &hostsApiList)
	if err != nil {
		return
	}

	statuses := map[string]int{}
	states := map[string]int{}

	for _, host := range hostsApiList {
		if _, ok := states[host.State]; ok {
			states[host.State]++
		} else {
			states[host.State] = 1
		}

		if _, ok := statuses[host.Status]; ok {
			statuses[host.Status]++
		} else {
			statuses[host.Status] = 1
		}
	}

	status.State = states
	status.Status = statuses

	rebuildStatus := weka.RebuildStatus{}
	err = jpool.Call(weka.JrpcRebuildStatus, struct{}{}, &rebuildStatus)
	if err != nil {
		return
	}

	status.ProtectionState = rebuildStatus.ProtectionState

	return
}
