package clusterize

import (
	"fmt"
	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
	"strconv"
	"strings"
)

func getAllBackendsIps(project, zone string, instancesNames []string) (backendsIps []string) {
	instances, err := common.GetInstances(project, zone, instancesNames)
	if err != nil {
		return
	}
	for _, instance := range instances {
		for _, networkInterface := range instance.NetworkInterfaces {
			backendsIps = append(backendsIps, *networkInterface.NetworkIP)
		}
	}
	return
}

func generateClusterizationScript(project, zone, hostsNum, nicsNum, gws, clusterName, nvmesMumber, usernameId, passwordId, clusterizeFinalizationUrl string, instancesNames []string) (clusterizeScript string) {
	log.Info().Msg("Generating clusterization scrtipt")
	instancesNamesStr := strings.Join(instancesNames, " ")
	creds, err := common.GetUsernameAndPassword(usernameId, passwordId)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}
	log.Info().Msgf("Fetched weka cluster creds successfully")

	clusterizeScriptTemplate := `
	#!/bin/bash

	set -ex
	IPS=%s
	HOSTS_NUM=%s
	NICS_NUM=%s
	GWS=%s
	CLUSTER_NAME=%s
	NVMES_NUM=%s
	ADMIN_USERNAME=%s
	ADMIN_PASSWORD=%s
	INSTANCE_NAMES="%s"
	CLUSTERIZE_FINALIZATION_URL=%s

	cluster_creation_str="weka cluster create $INSTANCE_NAMES"
	cluster_creation_str="$cluster_creation_str --host-ips "
	for (( i=0; i<$HOSTS_NUM; i++ )); do
		cluster_creation_str="$cluster_creation_str${IPS[$i*$NICS_NUM]},"
	done
	cluster_creation_str=${cluster_creation_str::-1}
	eval "$cluster_creation_str --admin-password $ADMIN_PASSWORD"
	
	weka user login "$ADMIN_USERNAME" "$ADMIN_PASSWORD"
	
	sleep 15s
	cores_num=$(expr $NICS_NUM - 1)
	for (( i=0; i<$HOSTS_NUM; i++ )); do weka cluster host cores $i $cores_num --frontend-dedicated-cores 1 --drives-dedicated-cores 1 ;done
	for (( i=0; i<$HOSTS_NUM; i++ )); do weka cluster host dedicate $i on ; done
	sleep 15s
	
	for (( i=1; i<$NICS_NUM; i++ )); do
		for (( j=0; j<$HOSTS_NUM; j++ )); do
			weka cluster host net add $j "eth$i" --ips ${IPS[$NICS_NUM*$j + $i]} --gateway ${GWS[$i]}
		done
	done
	
	sleep 15s
	for (( i=0; i<$HOSTS_NUM; i++ )); do
		for (( j=1; j<=$NVMES_NUM; j++ )); do
			weka cluster drive add $i "/dev/nvme0n$j";
		done
	done
	sleep 15s
	weka cluster hot-spare 1
	sleep 15s
	weka cluster update --cluster-name="$CLUSTER_NAME"
	sleep 15s
	weka cluster host activate
	sleep 15s
	weka cluster host apply --all --force
	sleep 30s
	weka cluster start-io
	echo "completed successfully" > /tmp/weka_clusterization_completion_validation

	curl $CLUSTERIZE_FINALIZATION_URL -H "Authorization:bearer $(gcloud auth print-identity-token)"
	`
	ips := fmt.Sprintf("(%s)", strings.Join(getAllBackendsIps(project, zone, instancesNames), " "))
	log.Info().Msgf("Formatting clusterization script template")
	clusterizeScript = fmt.Sprintf(dedent.Dedent(clusterizeScriptTemplate), ips, hostsNum, nicsNum, gws, clusterName, nvmesMumber, creds.Username, creds.Password, instancesNamesStr, clusterizeFinalizationUrl)
	return
}

func Clusterize(project, zone, hostsNum, nicsNum, gws, clusterName, nvmesMumber, usernameId, passwordId, bucket, instanceName, clusterizeFinalizationUrl string) (clusterizeScript string) {
	instancesNames, err := common.AddInstanceToStateInstances(bucket, instanceName)
	if err != nil {
		clusterizeScript = dedent.Dedent(`
		#!/bin/bash
		shutdown -P
		`)
		return
	}

	initialSize, err := strconv.Atoi(hostsNum)
	if err != nil {
		return
	}

	err = common.SetDeletionProtection(project, zone, instanceName)
	if err != nil {
		return
	}

	if len(instancesNames) == initialSize {
		clusterizeScript = generateClusterizationScript(project, zone, hostsNum, nicsNum, gws, clusterName, nvmesMumber, usernameId, passwordId, clusterizeFinalizationUrl, instancesNames)
	}

	return
}
