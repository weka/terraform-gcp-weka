package join_finalization

import (
	"context"
	"fmt"

	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/go-cloud-lib/protocol"
)

func JoinFinalization(ctx context.Context, project, zone, bucket, object, instanceGroup, instanceName string, protocolGw protocol.ProtocolGW) (err error) {
	err = common.SetDeletionProtection(ctx, project, zone, bucket, object, instanceName)
	if err != nil {
		log.Error().Err(err).Msg("Failed to set deletion protection")
		return
	}
	err = common.AddInstancesToGroup(ctx, project, zone, instanceGroup, []string{instanceName})
	if err != nil {
		log.Error().Err(err).Str("instance", instanceName).Str("group", instanceGroup).Msg("Failed to add instance to group")
		return
	}

	if protocolGw == protocol.NFS {
		// Add label to new NFS instance
		labels := map[string]string{
			common.NfsInterfaceGroupPortKey: common.NfsInterfaceGroupPortValue,
		}
		log.Info().Msgf("Adding label %s to NFS instance %s", common.NfsInterfaceGroupPortKey, instanceName)
		err := common.AddLabelsOnInstance(ctx, project, zone, instanceName, labels)
		if err != nil {
			err = fmt.Errorf("cannot add label %s to instance %s: %w", common.NfsInterfaceGroupPortKey, instanceName, err)
			common.ReportMsg(ctx, instanceName, bucket, object, "error", err.Error())
			log.Error().Err(err).Send()
		}
	}
	return
}
