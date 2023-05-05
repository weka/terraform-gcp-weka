package join_finalization

import (
	"context"

	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
)

func JoinFinalization(ctx context.Context, project, zone, instanceGroup, instanceName string) (err error) {
	err = common.SetDeletionProtection(ctx, project, zone, instanceName)
	if err != nil {
		return
	}
	err = common.AddInstancesToGroup(ctx, project, zone, instanceGroup, []string{instanceName})
	return
}
