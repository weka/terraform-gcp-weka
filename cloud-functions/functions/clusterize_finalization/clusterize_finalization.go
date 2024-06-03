package clusterize_finalization

import (
	"context"

	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/go-cloud-lib/protocol"
)

func ClusterizeFinalization(ctx context.Context, project, zone, instanceGroup, bucket string) (err error) {
	state, err := common.GetClusterState(ctx, bucket)
	if err != nil {
		return
	}

	instanceNames := common.GetInstancesNames(state.Instances)
	err = common.AddInstancesToGroup(ctx, project, zone, instanceGroup, instanceNames)
	if err != nil {
		return
	}

	state.Instances = []protocol.Vm{}
	state.Clusterized = true
	err = common.UpdateClusterState(ctx, bucket, state)

	return
}
