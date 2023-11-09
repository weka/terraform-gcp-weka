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
	"github.com/weka/go-cloud-lib/bash_functions"
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

func GetDeployScript(
	ctx context.Context,
	project,
	zone,
	instanceGroup,
	usernameId,
	passwordId,
	tokenId,
	bucket,
	instanceName,
	nicsNum,
	computeMemory,
	installUrl,
	proxyUrl,
	functionRootUrl,
	diskName string,
	computeContainerNum,
	frontendContainerNum,
	driveContainerNum int,
	gateways []string,
) (bashScript string, err error) {
	state, err := common.GetClusterState(ctx, bucket)
	if err != nil {
		return
	}
	funcDef := gcp_functions_def.NewFuncDef(functionRootUrl)
	// used for getting failure domain
	getHashedIpCommand := bash_functions.GetHashedPrivateIpBashCmd()
	instanceParams := protocol.BackendCoreCount{Compute: computeContainerNum, Frontend: frontendContainerNum, Drive: driveContainerNum, ComputeMemory: computeMemory}

	if !state.Clusterized {
		var token string
		token, err = getWekaIoToken(ctx, tokenId)
		if err != nil {
			return
		}

		deploymentParams := deploy.DeploymentParams{
			VMName:         instanceName,
			InstanceParams: instanceParams,
			WekaInstallUrl: installUrl,
			WekaToken:      token,
			NicsNum:        nicsNum,
			InstallDpdk:    true,
			Gateways:       gateways,
			ProxyUrl:       proxyUrl,
		}
		deployScriptGenerator := deploy.DeployScriptGenerator{
			FuncDef:          funcDef,
			Params:           deploymentParams,
			FailureDomainCmd: getHashedIpCommand,
			DeviceNameCmd:    GetDeviceName(diskName),
		}
		bashScript = deployScriptGenerator.GetDeployScript()
	} else {
		creds, err := common.GetUsernameAndPassword(ctx, usernameId, passwordId)
		if err != nil {
			log.Error().Msgf("Error while getting weka creds: %v", err)
			return "", err
		}

		instanceNames := common.GetInstanceGroupInstanceNames(ctx, project, zone, instanceGroup)
		instances, err := common.GetInstances(ctx, project, zone, instanceNames)
		if err != nil {
			return "", err
		}

		var ips []string
		for _, instance := range instances {
			ips = append(ips, *instance.NetworkInterfaces[0].NetworkIP)
		}
		if len(ips) == 0 {
			err = fmt.Errorf("no instances found for instance group %s, can't join", instanceGroup)
			return "", err
		}

		if err != nil {
			log.Error().Err(err).Send()
			return "", err
		}

		joinParams := join.JoinParams{
			WekaUsername:   creds.Username,
			WekaPassword:   creds.Password,
			IPs:            ips,
			InstallDpdk:    true,
			InstanceParams: instanceParams,
			Gateways:       gateways,
			ProxyUrl:       proxyUrl,
		}

		scriptBase := `
		#!/bin/bash
		set -ex
		`

		joinScriptGenerator := join.JoinScriptGenerator{
			FailureDomainCmd:   getHashedIpCommand,
			GetInstanceNameCmd: getGCPInstanceNameCmd(),
			FindDrivesScript:   dedent.Dedent(common.FindDrivesScript),
			ScriptBase:         dedent.Dedent(scriptBase),
			Params:             joinParams,
			FuncDef:            funcDef,
			DeviceNameCmd:      GetDeviceName(diskName),
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
