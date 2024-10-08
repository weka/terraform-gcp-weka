package fetch

import (
	"context"
	"fmt"
	"time"

	"github.com/rs/zerolog/log"

	"cloud.google.com/go/compute/apiv1/computepb"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/go-cloud-lib/lib/types"
	"github.com/weka/go-cloud-lib/protocol"
)

const defaultDownBackendsRemovalTimeout = 30 * time.Minute

type FetchInput struct {
	Project                    string
	Zone                       string
	InstanceGroup              string
	Bucket                     string
	StateObject                string
	DeploymentUsernameId       string
	DeploymentPasswordId       string
	AdminPasswordId            string
	DownBackendsRemovalTimeout time.Duration
	NFSInstanceGroup           string
	NFSStateObject             string
	ShowAdminPassword          bool
}

func FetchHostGroupInfo(ctx context.Context, params FetchInput) (hostGroupInfoResponse protocol.HostGroupInfoResponse, err error) {
	if params.DownBackendsRemovalTimeout == 0 {
		params.DownBackendsRemovalTimeout = defaultDownBackendsRemovalTimeout
	}

	instanceNames := common.GetInstanceGroupInstanceNames(ctx, params.Project, params.Zone, params.InstanceGroup)

	instances, err := common.GetInstances(ctx, params.Project, params.Zone, instanceNames)
	if err != nil {
		return
	}

	desiredCapacity, err := getCapacity(ctx, params.Bucket, params.StateObject)
	if err != nil {
		return
	}

	var wekaPassword string
	var adminPassword string
	var username string
	var creds protocol.ClusterCreds
	if params.ShowAdminPassword {
		creds, err = common.GetWekaAdminCredentials(ctx, params.Project, params.AdminPasswordId)
		if err != nil {
			err = fmt.Errorf("failed to get admin password: %w", err)
			log.Error().Err(err).Send()
			return
		}
		adminPassword = creds.Password

		creds, err = common.GetWekaDeploymentCredentials(ctx, params.Project, params.DeploymentUsernameId, params.DeploymentPasswordId)
		if err != nil {
			err = fmt.Errorf("failed to get deployment credentials: %w", err)
			log.Error().Err(err).Send()
			return
		}
		wekaPassword = creds.Password
		username = creds.Username
	} else {
		creds, err = common.GetDeploymentOrAdminUsernameAndPassword(ctx, params.Project, params.DeploymentUsernameId, params.DeploymentPasswordId, params.AdminPasswordId)
		if err != nil {
			err = fmt.Errorf("failed to get weka credentials: %w", err)
			log.Error().Err(err).Send()
			return
		}
		wekaPassword = creds.Password
		username = creds.Username
	}

	hostGroupInfoResponse = protocol.HostGroupInfoResponse{
		Username:                    username,
		Password:                    wekaPassword,
		AdminPassword:               adminPassword,
		WekaBackendsDesiredCapacity: desiredCapacity,
		WekaBackendInstances:        getHostGroupInfoInstances(instances),
		DownBackendsRemovalTimeout:  params.DownBackendsRemovalTimeout,
		BackendIps:                  common.GetInstanceGroupBackendsIps(instances),
		Role:                        "backend",
		Version:                     1,
	}

	if params.NFSStateObject != "" {
		nfsDesiredCapacity, err1 := getCapacity(ctx, params.Bucket, params.NFSStateObject)
		if err != nil {
			log.Error().Err(err).Send()
			err = err1
			return
		}

		nfsInstanceNames := common.GetInstanceGroupInstanceNames(ctx, params.Project, params.Zone, params.NFSInstanceGroup)
		nfsInstances, err1 := common.GetInstances(ctx, params.Project, params.Zone, nfsInstanceNames)
		if err != nil {
			log.Error().Err(err).Send()
			err = err1
			return
		}

		hostGroupInfoResponse.NfsBackendsDesiredCapacity = nfsDesiredCapacity
		hostGroupInfoResponse.NfsBackendInstances = getHostGroupInfoInstances(nfsInstances)
		hostGroupInfoResponse.NfsInterfaceGroupInstanceIps = getInterfaceGroupInstanceIps(nfsInstances, hostGroupInfoResponse.NfsBackendInstances)
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

func getInterfaceGroupInstanceIps(instances []*computepb.Instance, instancesInfo []protocol.HgInstance) (nfsInterfaceGroupInstanceIps map[string]types.Nilt) {
	vmIdsToPrivateIps := make(map[string]string, len(instancesInfo))
	for _, inst := range instancesInfo {
		vmIdsToPrivateIps[inst.Id] = inst.PrivateIp
	}

	nfsInterfaceGroupInstanceIps = make(map[string]types.Nilt)
	for _, instance := range instances {
		for key, val := range instance.Labels {
			if key == common.NfsInterfaceGroupPortKey && val == common.NfsInterfaceGroupPortValue {
				privateIp, ok := vmIdsToPrivateIps[fmt.Sprintf("%d", instance.Id)]
				if ok {
					nfsInterfaceGroupInstanceIps[privateIp] = types.Nilt{}
				}
			}
		}
	}
	return
}

func getCapacity(ctx context.Context, bucket, object string) (desired int, err error) {
	state, err := common.GetClusterState(ctx, bucket, object)
	if err != nil {
		return
	}
	desired = state.DesiredSize
	return
}
