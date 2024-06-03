package deploy

import (
	"context"
	"fmt"

	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	"cloud.google.com/go/secretmanager/apiv1/secretmanagerpb"
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
	client, err := secretmanager.NewClient(ctx)
	if err != nil {
		return
	}
	defer client.Close()

	res, err := client.AccessSecretVersion(ctx, &secretmanagerpb.AccessSecretVersionRequest{Name: tokenId})
	if err != nil {
		return
	}
	token = string(res.Payload.Data)
	return
}

type GCPDeploymentParams struct {
	Project              string
	Zone                 string
	InstanceGroup        string
	UsernameId           string
	PasswordId           string
	TokenId              string
	Bucket               string
	InstanceName         string
	NicsNumStr           string
	ComputeMemory        string
	InstallUrl           string
	ProxyUrl             string
	FunctionRootUrl      string
	DiskName             string
	ComputeContainerNum  int
	FrontendContainerNum int
	DriveContainerNum    int
	InstallDpdk          bool
	Gateways             []string
}

func GetDeployScript(ctx context.Context, p GCPDeploymentParams) (bashScript string, err error) {
	state, err := common.GetClusterState(ctx, p.Bucket)
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
			VMName:         p.InstanceName,
			InstanceParams: instanceParams,
			WekaInstallUrl: p.InstallUrl,
			WekaToken:      token,
			NicsNum:        p.NicsNumStr,
			InstallDpdk:    p.InstallDpdk,
			Gateways:       p.Gateways,
			ProxyUrl:       p.ProxyUrl,
		}
		deployScriptGenerator := deploy.DeployScriptGenerator{
			FuncDef:       funcDef,
			Params:        deploymentParams,
			DeviceNameCmd: GetDeviceName(p.DiskName),
		}
		bashScript = deployScriptGenerator.GetDeployScript()
	} else {
		creds, err := common.GetUsernameAndPassword(ctx, p.UsernameId, p.PasswordId)
		if err != nil {
			log.Error().Msgf("Error while getting weka creds: %v", err)
			return "", err
		}

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
			WekaUsername:   creds.Username,
			WekaPassword:   creds.Password,
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

func GetDeviceName(diskName string) string {
	template := "$(lsblk --output NAME,SERIAL --path --list --noheadings | grep %s | cut --delimiter ' ' --field 1)"
	return fmt.Sprintf(dedent.Dedent(template), diskName)
}
