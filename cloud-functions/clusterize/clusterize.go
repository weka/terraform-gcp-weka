package clusterize

import (
	compute "cloud.google.com/go/compute/apiv1"
	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	"context"
	"fmt"
	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"google.golang.org/api/iterator"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
	secretmanagerpb "google.golang.org/genproto/googleapis/cloud/secretmanager/v1"
	"net/http"
	"os"
	"strings"
)

type ClusterCreds struct {
	Username string
	Password string
}

func getUsernameAndPassword(usernameId, passwordId string) (clusterCreds ClusterCreds, err error) {
	ctx := context.Background()
	client, err := secretmanager.NewClient(ctx)
	if err != nil {
		return
	}
	defer client.Close()

	res, err := client.AccessSecretVersion(ctx, &secretmanagerpb.AccessSecretVersionRequest{Name: usernameId})
	if err != nil {
		return
	}
	clusterCreds.Username = string(res.Payload.Data)
	res, err = client.AccessSecretVersion(ctx, &secretmanagerpb.AccessSecretVersionRequest{Name: passwordId})
	if err != nil {
		return
	}
	clusterCreds.Password = string(res.Payload.Data)
	return
}

func getBackendsIps(project, zone, clusterName string) (backendsIps []string) {
	ctx := context.Background()
	instanceClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
	}
	defer instanceClient.Close()

	clusterNameFilter := fmt.Sprintf("labels.cluster_name=%s", clusterName)
	listInstanceRequest := &computepb.ListInstancesRequest{
		Project: project,
		Zone:    zone,
		Filter:  &clusterNameFilter,
	}

	listInstanceIter := instanceClient.List(ctx, listInstanceRequest)

	for {
		resp, err := listInstanceIter.Next()
		if err == iterator.Done {
			break
		}
		if err != nil {
			log.Error().Msgf("%s", err)
			break
		}
		for _, networkInterface := range resp.NetworkInterfaces {
			backendsIps = append(backendsIps, *networkInterface.NetworkIP)
		}

		_ = resp
	}
	return
}

func generateClusterizationScript(project, zone, hostsNum, nicsNum, gws, clusterName, nvmesMumber, usernameId, passwordId, instanceBaseName, cloudFunctionUrl string) (clusterizeScript string) {
	log.Info().Msg("Generating clusterization scrtipt")
	creds, err := getUsernameAndPassword(usernameId, passwordId)
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
	INSTANCE_NAME=%s
	CLOUD_FUNCTION_URL=%s

	other_hosts_num=$(expr $HOSTS_NUM - 1)
	while [ $(curl --silent $CLOUD_FUNCTION_URL) -lt $other_hosts_num ] ; do
		echo "waiting for other hosts before clusterizing..."
		sleep 10
	done

	cluster_creation_str="weka cluster create"
	for (( i=0; i<$HOSTS_NUM; i++ )); do
		cluster_creation_str="$cluster_creation_str $INSTANCE_NAME-$i"
	done
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
	`
	ips := fmt.Sprintf("(%s)", strings.Join(getBackendsIps(project, zone, clusterName), " "))
	log.Info().Msgf("Formatting clusterization script template")
	clusterizeScript = fmt.Sprintf(dedent.Dedent(clusterizeScriptTemplate), ips, hostsNum, nicsNum, gws, clusterName, nvmesMumber, creds.Username, creds.Password, instanceBaseName, cloudFunctionUrl)
	return
}

func Clusterize(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	hostsNum := os.Getenv("HOSTS_NUM")
	nicsNum := os.Getenv("NICS_NUM")
	gws := os.Getenv("GWS")
	clusterName := os.Getenv("CLUSTER_NAME")
	nvmesMumber := os.Getenv("NVMES_NUM")
	usernameId := os.Getenv("USER_NAME_ID")
	passwordId := os.Getenv("PASSWORD_ID")
	instanceBaseName := os.Getenv("INSTANCE_BASE_NAME")
	cloudFunctionUrl := os.Getenv("CLOUD_FUNCTION_URL")

	fmt.Fprintf(w, generateClusterizationScript(project, zone, hostsNum, nicsNum, gws, clusterName, nvmesMumber, usernameId, passwordId, instanceBaseName, cloudFunctionUrl))
}
