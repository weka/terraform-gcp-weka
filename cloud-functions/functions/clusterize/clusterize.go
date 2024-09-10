package clusterize

import (
	"context"
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/weka/go-cloud-lib/functions_def"

	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/gcp_functions_def"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/functions/report"
	"github.com/weka/go-cloud-lib/clusterize"
	cloudCommon "github.com/weka/go-cloud-lib/common"
	"github.com/weka/go-cloud-lib/protocol"
	"github.com/weka/go-cloud-lib/utils"
)

type ClusterizationParams struct {
	Project              string
	Region               string
	Zone                 string
	UsernameId           string
	AdminPasswordId      string
	DeploymentPasswordId string
	Bucket               string
	StateObject          string
	Vm                   protocol.Vm
	Cluster              clusterize.ClusterParams
	Obs                  protocol.ObsParams
	// root url for cloud function calls' definitions
	CloudFuncRootUrl string
	NvmesNum         int
	NFSParams        protocol.NFSParams
	NFSStateObject   string
	BackendLbIp      string
}

func GetSelfDeletingScriptWithReport(message, cloudFuncRootUrl string, vm protocol.Vm) string {
	funcDef := gcp_functions_def.NewFuncDef(cloudFuncRootUrl)
	reportFunctionDef := funcDef.GetFunctionCmdDefinition(functions_def.Report)

	s := `
	#!/bin/bash

	instance_name=%s

	# report function definition
	%s

	PROTOCOL="%s"
	report "{\"hostname\": \"$HOSTNAME\", \"protocol\": \"$PROTOCOL\", \"type\": \"progress\", \"message\": \"Self-terminating: %s\"}"

	self_deleting() {
		echo "self deleting..."
		zone=$(curl -X GET http://metadata.google.internal/computeMetadata/v1/instance/zone -H 'Metadata-Flavor: Google')
		gcloud compute instances update $instance_name --no-deletion-protection --zone=$zone
		gcloud --quiet compute instances delete $instance_name --zone=$zone
	}

	self_deleting || shutdown -P
	`
	return fmt.Sprintf(dedent.Dedent(s), vm.Name, reportFunctionDef, vm.Protocol, message)
}

func ReportErrorAndTerminateInstance(ctx context.Context, p ClusterizationParams, err error) error {
	object := p.StateObject
	if p.Vm.Protocol == protocol.NFS {
		object = p.NFSStateObject
	}
	msg := fmt.Sprintf("Terminating instance due to error: %v", err)
	common.ReportMsg(ctx, p.Vm.Name, p.Bucket, object, "progress", msg)

	_, errs := common.TerminateInstances(ctx, p.Project, p.Zone, []string{p.Vm.Name})
	if len(errs) > 0 {
		err := fmt.Errorf("failed to terminate instance %s: %s", p.Vm.Name, errs[0])
		log.Error().Err(err).Send()
		common.ReportMsg(ctx, p.Vm.Name, p.Bucket, object, "progress", err.Error())
		return err
	}
	return nil
}

func NFSClusterize(ctx context.Context, p ClusterizationParams) (clusterizeScript string) {
	nfsInterfaceGroupName := os.Getenv("NFS_INTERFACE_GROUP_NAME")
	nfsProtocolgwsNum, _ := strconv.Atoi(os.Getenv("NFS_PROTOCOL_GATEWAYS_NUM"))
	nfsSecondaryIpsNum, _ := strconv.Atoi(os.Getenv("NFS_SECONDARY_IPS_NUM"))

	funcDef := gcp_functions_def.NewFuncDef(p.CloudFuncRootUrl)
	reportFunction := funcDef.GetFunctionCmdDefinition(functions_def.Report)

	state, err := common.AddInstanceToStateInstances(ctx, p.Bucket, p.NFSStateObject, p.Vm)
	if err != nil {
		var e *common.ExtraInstanceForClusterizationError
		if errors.As(err, &e) {
			err1 := ReportErrorAndTerminateInstance(ctx, p, err)
			if err1 != nil {
				log.Error().Err(err1).Send()
				return GetSelfDeletingScriptWithReport(err.Error(), p.CloudFuncRootUrl, p.Vm)
			}
			return
		}
		clusterizeScript = cloudCommon.GetErrorScript(err, reportFunction, p.Vm.Protocol)
		return
	}

	err = common.SetDeletionProtection(ctx, p.Project, p.Zone, p.Bucket, p.NFSStateObject, p.Vm.Name)
	if err != nil {
		clusterizeScript = cloudCommon.GetErrorScript(err, reportFunction, p.Vm.Protocol)
		return
	}

	msg := fmt.Sprintf("This (%s) is nfs instance %d/%d that is ready for joining the interface group", p.Vm.Name, len(state.Instances), nfsProtocolgwsNum)
	log.Info().Msgf(msg)
	if len(state.Instances) != nfsProtocolgwsNum {
		clusterizeScript = cloudCommon.GetScriptWithReport(msg, reportFunction, p.Vm.Protocol)
		return
	}

	var containersUid []string
	var nicNames []string
	for _, instance := range state.Instances {
		containersUid = append(containersUid, instance.ContainerUid)
		nicNames = append(nicNames, instance.NicName)
	}

	// TODO: add nfsSecondaryIpsNum check
	secondaryIps := make([]string, 0, nfsSecondaryIpsNum)

	nfsParams := protocol.NFSParams{
		InterfaceGroupName: nfsInterfaceGroupName,
		SecondaryIps:       secondaryIps,
		ContainersUid:      containersUid,
		NicNames:           nicNames,
		HostsNum:           nfsProtocolgwsNum,
	}

	scriptGenerator := clusterize.ConfigureNfsScriptGenerator{
		Params:         nfsParams,
		FuncDef:        funcDef,
		LoadBalancerIP: p.BackendLbIp,
		Name:           p.Vm.Name,
	}

	err = common.UpdateStateNfsMigrated(ctx, p.Bucket, p.NFSStateObject)
	if err != nil {
		clusterizeScript = cloudCommon.GetErrorScript(err, reportFunction, p.Vm.Protocol)
		return
	}
	clusterizeScript = scriptGenerator.GetNFSSetupScript()
	log.Info().Msg("Clusterization script for NFS generated")
	return
}

func Clusterize(ctx context.Context, p ClusterizationParams) (clusterizeScript string) {
	funcDef := gcp_functions_def.NewFuncDef(p.CloudFuncRootUrl)
	reportFunction := funcDef.GetFunctionCmdDefinition(functions_def.Report)

	state, err := common.AddInstanceToStateInstances(ctx, p.Bucket, p.StateObject, p.Vm)
	if err != nil {
		var e *common.ExtraInstanceForClusterizationError
		if errors.As(err, &e) {
			err1 := ReportErrorAndTerminateInstance(ctx, p, err)
			if err1 != nil {
				log.Error().Err(err1).Send()
				return GetSelfDeletingScriptWithReport(err.Error(), p.CloudFuncRootUrl, p.Vm)
			}
			return
		}
		clusterizeScript = cloudCommon.GetErrorScript(err, reportFunction, p.Vm.Protocol)
		return
	}

	err = common.SetDeletionProtection(ctx, p.Project, p.Zone, p.Bucket, p.StateObject, p.Vm.Name)
	if err != nil {
		clusterizeScript = cloudCommon.GetErrorScript(err, reportFunction, p.Vm.Protocol)
		return
	}

	msg := fmt.Sprintf("This (%s) is instance %d/%d that is ready for clusterization", p.Vm.Name, len(state.Instances), state.ClusterizationTarget)
	log.Info().Msgf(msg)
	if len(state.Instances) != p.Cluster.ClusterizationTarget {
		clusterizeScript = cloudCommon.GetScriptWithReport(msg, reportFunction, p.Vm.Protocol)
		return
	}

	if p.Cluster.SetObs {
		if p.Obs.Name == "" {
			p.Obs.Name = strings.Join([]string{p.Project, p.Cluster.Prefix, p.Cluster.ClusterName, "obs"}, "-")
			err = common.CreateBucket(ctx, p.Project, p.Region, p.Obs.Name)
			if err != nil {
				log.Error().Err(err).Send()
				err = report.Report(
					ctx,
					protocol.Report{
						Type:     "error",
						Hostname: p.Vm.Name,
						Message:  fmt.Sprintf("Failed creating obs bucket %s: %s", p.Obs.Name, err),
					},
					p.Bucket,
					p.StateObject,
				)
				if err != nil {
					log.Error().Err(err).Send()
				}
			}
		} else {
			log.Info().Msgf("Using existing obs bucket %s", p.Obs.Name)
		}
	}

	log.Info().Msg("setting weka admin password in secrets manager")
	adminPassword := utils.GeneratePassword(16, 1, 1, 1)
	err = common.SetSecretVersion(ctx, p.AdminPasswordId, adminPassword)
	if err != nil {
		log.Error().Err(err).Send()
		clusterizeScript = cloudCommon.GetErrorScript(err, reportFunction, p.Vm.Protocol)
		return
	}

	log.Info().Msg("setting weka deployment password in secrets manager")
	wekaDeploymentPassword := utils.GeneratePassword(16, 1, 1, 1)
	err = common.SetSecretVersion(ctx, p.DeploymentPasswordId, wekaDeploymentPassword)
	if err != nil {
		log.Error().Err(err).Send()
		clusterizeScript = cloudCommon.GetErrorScript(err, reportFunction, p.Vm.Protocol)
		return
	}

	instancesNames := common.GetInstancesNames(state.Instances)
	ips := common.GetBackendsIps(ctx, p.Project, p.Zone, instancesNames)

	clusterParams := p.Cluster
	clusterParams.VMNames = instancesNames
	clusterParams.IPs = ips
	clusterParams.ObsScript = GetObsScript(p.Obs)
	clusterParams.FindDrivesScript = dedent.Dedent(common.FindDrivesScript)
	clusterParams.InstallDpdk = true
	if p.NvmesNum > 8 {
		clusterParams.PostClusterCreationScript = GetPostClusterCreationScript(p.Cluster.ClusterizationTarget)
	}

	scriptGenerator := clusterize.ClusterizeScriptGenerator{
		Params:  clusterParams,
		FuncDef: funcDef,
	}
	clusterizeScript = scriptGenerator.GetClusterizeScript()

	log.Info().Msg("Clusterization script generated")
	return
}

func GetObsScript(obsParams protocol.ObsParams) string {
	template := `
	OBS_TIERING_SSD_PERCENT=%s
	OBS_NAME="%s"

	weka fs tier s3 add gcp-bucket --hostname storage.googleapis.com --port 443 --bucket "$OBS_NAME" --protocol https --auth-method AWSSignature4
	weka fs tier s3 attach default gcp-bucket
	tiering_percent=$(echo "$full_capacity * 100 / $OBS_TIERING_SSD_PERCENT" | bc)
	weka fs update default --total-capacity "$tiering_percent"B
	`
	return fmt.Sprintf(
		dedent.Dedent(template), obsParams.TieringSsdPercent, obsParams.Name,
	)
}

func GetPostClusterCreationScript(clusterizationTarget int) string {
	template := `
	DRIVE_PROCESSES=%d # UDP and DPDK
	function wait_for_apply_completion() {
		# wait for some process to be DOWN
		while ! weka cluster process 2>/dev/null | grep -q DOWN; do
			echo "Waiting for apply to start"
			sleep 1
		done

		# while loop until all processes are UP
		count=0
		while [ $count -lt $DRIVE_PROCESSES ]; do
			echo "Waiting for apply to finish"
			sleep 1
			count=$(weka cluster process | grep drives0 | grep UP | wc -l || true)
		done
	}

	echo "Running disks override"
	weka debug override add --key override_max_disks_in_node --value 32
	weka cluster container | grep drives0 | awk '{print $1}' | xargs -IH weka cluster container dedicate H off
	weka cluster container apply -f --all
	wait_for_apply_completion
	weka cluster container | grep drives0 | awk '{print $1}' | xargs -IH weka cluster container dedicate H on
	weka cluster container apply -f --all
	wait_for_apply_completion
	`
	return fmt.Sprintf(
		dedent.Dedent(template), clusterizationTarget*2,
	)
}
