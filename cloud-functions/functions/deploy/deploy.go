package deploy

import (
	"context"
	"fmt"

	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/gcp_functions_def"
	"github.com/weka/go-cloud-lib/deploy"
	"github.com/weka/go-cloud-lib/join"
	"github.com/weka/go-cloud-lib/protocol"
)

func getGCPInstanceNameCmd() string {
	return "echo $HOSTNAME"
}

func getWekaIoToken(ctx context.Context, tokenId string) (token string, err error) {
	token, err = common.GetSecret(ctx, tokenId)
	return
}

type GCPDeploymentParams struct {
	Project               string
	Zone                  string
	InstanceGroup         string
	TokenId               string // we allow empty token id for private network installation
	Bucket                string
	StateObject           string
	InstanceName          string
	NicsNumStr            string
	NvmesNum              int
	ComputeMemory         string
	InstallUrl            string
	ProxyUrl              string
	FunctionRootUrl       string
	DiskName              string
	ComputeContainerNum   int
	FrontendContainerNum  int
	DriveContainerNum     int
	InstallDpdk           bool
	Gateways              []string
	BackendLbIp           string
	NFSStateObject        string
	NFSInstanceGroup      string
	NFSInterfaceGroupName string
	NFSProtocolGWsNum     int
	NFSGatewayFeCoresNum  int
	NFSSecondaryIpsNum    int
	NFSDiskSize           int
	SMBGatewayFeCoresNum  int
	SMBDiskSize           int
	S3GatewayFeCoresNum   int
	S3DiskSize            int
}

func GetBackendsDeployScript(ctx context.Context, p GCPDeploymentParams) (bashScript string, err error) {
	state, err := common.GetClusterState(ctx, p.Bucket, p.StateObject)
	if err != nil {
		return
	}
	funcDef := gcp_functions_def.NewFuncDef(p.FunctionRootUrl)

	instanceParams := protocol.BackendCoreCount{
		Compute:       p.ComputeContainerNum,
		Frontend:      p.FrontendContainerNum,
		Drive:         p.DriveContainerNum,
		ComputeMemory: p.ComputeMemory,
	}

	if !state.Clusterized {
		var token string
		// we allow empty token id for private network installation
		if p.TokenId != "" {
			token, err = getWekaIoToken(ctx, p.TokenId)
			if err != nil {
				return
			}
		}

		deploymentParams := deploy.DeploymentParams{
			VMName:           p.InstanceName,
			InstanceParams:   instanceParams,
			WekaInstallUrl:   p.InstallUrl,
			WekaToken:        token,
			NicsNum:          p.NicsNumStr,
			InstallDpdk:      p.InstallDpdk,
			Gateways:         p.Gateways,
			ProxyUrl:         p.ProxyUrl,
			NvmesNum:         p.NvmesNum,
			FindDrivesScript: dedent.Dedent(common.FindDrivesScript),
		}
		deployScriptGenerator := deploy.DeployScriptGenerator{
			FuncDef:       funcDef,
			Params:        deploymentParams,
			DeviceNameCmd: GetDeviceName(p.DiskName),
		}
		bashScript = deployScriptGenerator.GetDeployScript()
	} else {
		instanceNames := common.GetInstanceGroupInstanceNames(ctx, p.Project, p.Zone, p.InstanceGroup)
		instances, err := common.GetInstances(ctx, p.Project, p.Zone, instanceNames)
		if err != nil {
			log.Error().Err(err).Send()
			return "", err
		}

		ips := common.GetInstanceGroupBackendsIps(instances)
		if len(ips) == 0 {
			err = fmt.Errorf("no instances found for instance group %s, can't join", p.InstanceGroup)
			return "", err
		}

		joinParams := join.JoinParams{
			IPs:            ips,
			InstallDpdk:    p.InstallDpdk,
			InstanceParams: instanceParams,
			Gateways:       p.Gateways,
			ProxyUrl:       p.ProxyUrl,
		}

		scriptBase := `
		#!/bin/bash
		set -ex
		`

		joinScriptGenerator := join.JoinScriptGenerator{
			GetInstanceNameCmd: getGCPInstanceNameCmd(),
			FindDrivesScript:   dedent.Dedent(common.FindDrivesScript),
			ScriptBase:         dedent.Dedent(scriptBase),
			Params:             joinParams,
			FuncDef:            funcDef,
			DeviceNameCmd:      GetDeviceName(p.DiskName),
		}
		bashScript = joinScriptGenerator.GetJoinScript(ctx)
	}
	bashScript = dedent.Dedent(bashScript)
	return
}

func GetNfsDeployScript(ctx context.Context, p GCPDeploymentParams) (bashScript string, err error) {
	log.Info().Msg("Getting NFS deploy script")

	state, err := common.GetClusterState(ctx, p.Bucket, p.NFSStateObject)
	if err != nil {
		log.Error().Err(err).Send()
		return
	}

	var token string
	// we allow empty token id for private network installation
	if p.TokenId != "" {
		token, err = getWekaIoToken(ctx, p.TokenId)
		if err != nil {
			return
		}
	}

	funcDef := gcp_functions_def.NewFuncDef(p.FunctionRootUrl)

	deploymentParams := deploy.DeploymentParams{
		VMName:                    p.InstanceName,
		WekaInstallUrl:            p.InstallUrl,
		WekaToken:                 token,
		NicsNum:                   p.NicsNumStr,
		InstallDpdk:               p.InstallDpdk,
		ProxyUrl:                  p.ProxyUrl,
		Gateways:                  p.Gateways,
		Protocol:                  protocol.NFS,
		NFSInterfaceGroupName:     p.NFSInterfaceGroupName,
		NFSSecondaryIpsNum:        p.NFSSecondaryIpsNum,
		ProtocolGatewayFeCoresNum: p.NFSGatewayFeCoresNum,
		LoadBalancerIP:            p.BackendLbIp,
	}

	if !state.Clusterized {
		deployScriptGenerator := deploy.DeployScriptGenerator{
			FuncDef:       funcDef,
			Params:        deploymentParams,
			DeviceNameCmd: GetDeviceNameFromDiskSize(p.NFSDiskSize),
		}
		bashScript = deployScriptGenerator.GetDeployScript()
	} else {
		joinScriptGenerator := join.JoinNFSScriptGenerator{
			DeviceNameCmd:      GetDeviceNameFromDiskSize(p.NFSDiskSize),
			DeploymentParams:   deploymentParams,
			InterfaceGroupName: p.NFSInterfaceGroupName,
			FuncDef:            funcDef,
			Name:               p.InstanceName,
		}
		bashScript = joinScriptGenerator.GetJoinNFSHostScript()
	}

	return
}

func GetProtocolDeployScript(ctx context.Context, p GCPDeploymentParams, protocolGw protocol.ProtocolGW) (bashScript string, err error) {
	log.Info().Str("protocol", string(protocolGw)).Msgf("Getting deploy script")

	var token string
	if p.TokenId != "" {
		token, err = getWekaIoToken(ctx, p.TokenId)
		if err != nil {
			return
		}
	}

	var protocolGatewayFeCoresNum int
	var diskSize int
	if protocolGw == protocol.SMB || protocolGw == protocol.SMBW {
		protocolGatewayFeCoresNum = p.SMBGatewayFeCoresNum
		diskSize = p.SMBDiskSize
	} else if protocolGw == protocol.S3 {
		protocolGatewayFeCoresNum = p.S3GatewayFeCoresNum
		diskSize = p.S3DiskSize
	}

	deploymentParams := deploy.DeploymentParams{
		VMName:                    p.InstanceName,
		WekaInstallUrl:            p.InstallUrl,
		WekaToken:                 token,
		NicsNum:                   p.NicsNumStr,
		InstallDpdk:               p.InstallDpdk,
		ProxyUrl:                  p.ProxyUrl,
		Protocol:                  protocolGw,
		ProtocolGatewayFeCoresNum: protocolGatewayFeCoresNum,
		Gateways:                  p.Gateways,
		LoadBalancerIP:            p.BackendLbIp,
	}

	funcDef := gcp_functions_def.NewFuncDef(p.FunctionRootUrl)

	deployScriptGenerator := deploy.DeployScriptGenerator{
		FuncDef:       funcDef,
		Params:        deploymentParams,
		DeviceNameCmd: GetDeviceNameFromDiskSize(diskSize),
	}
	bashScript = deployScriptGenerator.GetDeployScript()
	return
}

func GetDeviceName(diskName string) string {
	template := "$(lsblk --output NAME,SERIAL --path --list --noheadings | grep %s | cut --delimiter ' ' --field 1)"
	return fmt.Sprintf(dedent.Dedent(template), diskName)
}

func GetDeviceNameFromDiskSize(diskSize int) string {
	// wekaiosw_device=/dev/"$(lsblk | grep ${disk_size}G | awk '{print $1}')"
	template := "/dev/\"$(lsblk | grep %dG | awk '{print $1}')\""
	return fmt.Sprintf(template, diskSize)
}
