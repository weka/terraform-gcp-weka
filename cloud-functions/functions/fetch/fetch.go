package fetch

import (
	compute "cloud.google.com/go/compute/apiv1"
	"context"
	"fmt"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/cloud-functions/common"
	"google.golang.org/api/iterator"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
	"strings"
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

func GetFetchDataParams(project, zone, instanceGroup, clusterName, collectionName, documentName, usernameId, passwordId string) (hostGroupInfoResponse HostGroupInfoResponse) {

	creds, err := common.GetUsernameAndPassword(usernameId, passwordId)
	if err != nil {
		return
	}

	instances, err := common.GetInstances(project, zone, getInstancesNames(project, zone, instanceGroup))
	if err != nil {
		return
	}

	return HostGroupInfoResponse{
		Username:        creds.Username,
		Password:        creds.Password,
		DesiredCapacity: getCapacity(project, collectionName, documentName),
		Instances:       getHostGroupInfoInstances(instances),
		BackendIps:      common.GetBackendsIps(project, zone, clusterName),
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

func getCapacity(project, collectionName, documentName string) int {
	info := common.GetClusterSizeInfo(project, collectionName, documentName)
	return int(info["desired_size"].(int64))
}

func getInstancesNames(project, zone, instanceGroup string) (instanceNames []string) {
	ctx := context.Background()

	c, err := compute.NewInstanceGroupsRESTClient(ctx)
	if err != nil {
		log.Fatal().Err(err)
	}
	defer c.Close()

	req := &computepb.ListInstancesInstanceGroupsRequest{
		Project:       project,
		Zone:          zone,
		InstanceGroup: instanceGroup,
	}
	it := c.ListInstances(ctx, req)

	for {
		resp, err := it.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Fatal().Err(err)
			break
		}
		split := strings.Split(resp.GetInstance(), "/")
		instanceNames = append(instanceNames, split[len(split)-1])
		log.Info().Msgf("%s", split[len(split)-1])
		_ = resp
	}
	return
}
