package deploy

import (
	"context"
	"fmt"
	"strings"

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

func GetBackendCoreCount(machineType string) (backendCoreCount protocol.BackendCoreCount, err error) {
	switch machineType {
	case "c2-standard-8":
		backendCoreCount = protocol.BackendCoreCount{Total: 3, Frontend: 1, Drive: 1, Memory: "8033846653B"}
	case "c2-standard-16":
		backendCoreCount = protocol.BackendCoreCount{Total: 6, Frontend: 1, Drive: 1, Memory: "23156228928B"}
	default:
		err = fmt.Errorf("unsupported GCP machine type: %s", machineType)
	}
	return backendCoreCount, err
}

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
	computeMemory,
	computeContainerNum,
	frontendContainerNum,
	driveContainerNum,
	nicsNum,
	installUrl string,
	gateways []string,
) (bashScript string, err error) {
	state, err := common.GetClusterState(ctx, bucket)
	if err != nil {
		return
	}
	funcDef := gcp_functions_def.NewFuncDef()
	// used for getting failure domain
	getHashedIpCommand := bash_functions.GetHashedPrivateIpBashCmd()

	if !state.Clusterized {
		var token string
		token, err = getWekaIoToken(ctx, tokenId)
		if err != nil {
			return
		}

		deploymentParams := deploy.DeploymentParams{
			VMName:               instanceName,
			ComputeMemory:        computeMemory,
			ComputeContainerNum:  computeContainerNum,
			FrontendContainerNum: frontendContainerNum,
			DriveContainerNum:    driveContainerNum,
			WekaInstallUrl:       installUrl,
			WekaToken:            token,
			NicsNum:              nicsNum,
			InstallDpdk:          true,
			Gateways:             gateways,
		}
		deployScriptGenerator := deploy.DeployScriptGenerator{
			FuncDef:          funcDef,
			Params:           deploymentParams,
			FailureDomainCmd: getHashedIpCommand,
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

		instanceTypeParts := strings.Split(*instances[0].MachineType, "/")
		instanceType := instanceTypeParts[len(instanceTypeParts)-1]

		instanceParams, err := GetBackendCoreCount(instanceType)
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
		}

		scriptBase := `
		#!/bin/bash
		set -ex
		`

		findDrivesScript := `
		import json
		import sys
		for d in json.load(sys.stdin)['disks']:
			if d['isRotational']: continue
			if d['type'] != 'DISK': continue
			if d['isMounted']: continue
			if d['model'] != 'nvme_card': continue
			print(d['devPath'])
		`
		joinScriptGenerator := join.JoinScriptGenerator{
			FailureDomainCmd:   getHashedIpCommand,
			GetInstanceNameCmd: getGCPInstanceNameCmd(),
			FindDrivesScript:   dedent.Dedent(findDrivesScript),
			ScriptBase:         dedent.Dedent(scriptBase),
			Params:             joinParams,
			FuncDef:            funcDef,
		}
		bashScript = joinScriptGenerator.GetJoinScript(ctx)
	}
	bashScript = dedent.Dedent(bashScript)
	return
}
