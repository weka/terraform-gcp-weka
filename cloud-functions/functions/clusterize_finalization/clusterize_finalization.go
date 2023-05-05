package clusterize_finalization

import (
	"context"

	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
)

func ClusterizeFinalization(ctx context.Context, project, zone, instanceGroup, bucket string) (err error) {
	state, err := common.GetClusterState(ctx, bucket)
	if err != nil {
		return
	}
	err = common.AddInstancesToGroup(ctx, project, zone, instanceGroup, state.Instances)
	if err != nil {
		return
	}

	state.Instances = []string{}
	state.Clusterized = true
	err = common.UpdateClusterState(ctx, bucket, state)

	return
}
