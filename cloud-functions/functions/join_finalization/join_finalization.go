package join_finalization

import "github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"

func JoinFinalization(project, zone, instanceGroup, instanceName string) (err error) {
	err = common.SetDeletionProtection(project, zone, instanceName)
	if err != nil {
		return
	}
	err = common.AddInstancesToGroup(project, zone, instanceGroup, []string{instanceName})
	return
}
