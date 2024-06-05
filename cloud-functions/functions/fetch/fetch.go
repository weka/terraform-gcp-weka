package fetch

import (
	"context"
	"fmt"
	"time"

	"cloud.google.com/go/compute/apiv1/computepb"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/go-cloud-lib/protocol"
)

const defaultDownBackendsRemovalTimeout = 30 * time.Minute

func GetFetchDataParams(
	ctx context.Context, project, zone, instanceGroup, bucket, usernameId, passwordId string, downBackendsRemovalTimeout time.Duration,
) (hostGroupInfoResponse protocol.HostGroupInfoResponse, err error) {
	if downBackendsRemovalTimeout == 0 {
		downBackendsRemovalTimeout = defaultDownBackendsRemovalTimeout
	}

	creds, err := common.GetUsernameAndPassword(ctx, usernameId, passwordId)
	if err != nil {
		return
	}

	instances, err := common.GetInstances(ctx, project, zone, common.GetInstanceGroupInstanceNames(ctx, project, zone, instanceGroup))
	if err != nil {
		return
	}

	desiredCapacity, err := getCapacity(ctx, bucket)
	if err != nil {
		return
	}

	hostGroupInfoResponse = protocol.HostGroupInfoResponse{
		Username:                    creds.Username,
		Password:                    creds.Password,
		WekaBackendsDesiredCapacity: desiredCapacity,
		WekaBackendInstances:        getHostGroupInfoInstances(instances),
		DownBackendsRemovalTimeout:  downBackendsRemovalTimeout,
		BackendIps:                  common.GetInstanceGroupBackendsIps(instances),
		Role:                        "backend",
		Version:                     1,
	}
	return
}

func getHostGroupInfoInstances(instances []*computepb.Instance) (ret []protocol.HgInstance) {
	for _, i := range instances {
		if i.Id != nil && len(i.NetworkInterfaces) > 0 {
			ret = append(ret, protocol.HgInstance{
				Id:        fmt.Sprintf("%d", i.Id),
				PrivateIp: *i.NetworkInterfaces[0].NetworkIP,
			})
		}
	}
	return
}

func getCapacity(ctx context.Context, bucket string) (desired int, err error) {
	state, err := common.GetClusterState(ctx, bucket)
	if err != nil {
		return
	}
	desired = state.DesiredSize
	return
}
