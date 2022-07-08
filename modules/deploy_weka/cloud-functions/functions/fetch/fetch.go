package fetch

import (
	"fmt"
	"github.com/weka/gcp-tf/cloud-functions/common"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
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

func getInstanceGroupBackendsIps(instances []*computepb.Instance) (instanceGroupBackendsIps []string) {
	for _, instance := range instances {
		instanceGroupBackendsIps = append(instanceGroupBackendsIps, *instance.NetworkInterfaces[0].NetworkIP)
	}
	return
}

func GetFetchDataParams(project, zone, instanceGroup, bucket, usernameId, passwordId string) (hostGroupInfoResponse HostGroupInfoResponse) {

	creds, err := common.GetUsernameAndPassword(usernameId, passwordId)
	if err != nil {
		return
	}

	instances, err := common.GetInstances(project, zone, common.GetInstanceGroupInstanceNames(project, zone, instanceGroup))
	if err != nil {
		return
	}

	return HostGroupInfoResponse{
		Username:        creds.Username,
		Password:        creds.Password,
		DesiredCapacity: getCapacity(bucket),
		Instances:       getHostGroupInfoInstances(instances),
		BackendIps:      getInstanceGroupBackendsIps(instances),
		Role:            "backend",
		Version:         1,
	}
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

func getCapacity(bucket string) int {
	state, err := common.GetClusterState(bucket)
	if err != nil {
		return -1
	}
	return state.DesiredSize
}
