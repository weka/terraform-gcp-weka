package fetch

import (
	"context"
	"fmt"

	"cloud.google.com/go/compute/apiv1/computepb"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
)

type HgInstance struct {
	Id        string
	PrivateIp string
}

type HostGroupInfoResponse struct {
	Username        string       `json:"username"`
	Password        string       `json:"password"`
	DesiredCapacity int          `json:"desired_capacity"`
	Instances       []HgInstance `json:"instances"`
	BackendIps      []string     `json:"backend_ips"`
	Role            string       `json:"role"`
	Version         int          `json:"version"`
}

func GetFetchDataParams(
	ctx context.Context, project, zone, instanceGroup, bucket, usernameId, passwordId string,
) (hostGroupInfoResponse HostGroupInfoResponse, err error) {
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

	hostGroupInfoResponse = HostGroupInfoResponse{
		Username:        creds.Username,
		Password:        creds.Password,
		DesiredCapacity: desiredCapacity,
		Instances:       getHostGroupInfoInstances(instances),
		BackendIps:      common.GetInstanceGroupBackendsIps(instances),
		Role:            "backend",
		Version:         1,
	}

	return
}

func getHostGroupInfoInstances(instances []*computepb.Instance) (ret []HgInstance) {
	for _, i := range instances {
		if i.Id != nil && len(i.NetworkInterfaces) > 0 {
			ret = append(ret, HgInstance{
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
