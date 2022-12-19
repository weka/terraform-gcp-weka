package clusterize_finalization

import "github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"

func ClusterizeFinalization(project, zone, instanceGroup, bucket string) (err error) {
	state, err := common.GetClusterState(bucket)
	if err != nil {
		return
	}
	err = common.AddInstancesToGroup(project, zone, instanceGroup, state.Instances)
	if err != nil {
		return
	}

	state.Instances = []string{}
	state.Clusterized = true
	err = common.UpdateClusterState(bucket, state)

	return
}
