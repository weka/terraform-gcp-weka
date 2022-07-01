package deploy

import (
	compute "cloud.google.com/go/compute/apiv1"
	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	"context"
	"errors"
	firebase "firebase.google.com/go"
	"fmt"
	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"google.golang.org/api/iterator"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
	secretmanagerpb "google.golang.org/genproto/googleapis/cloud/secretmanager/v1"
	"math/rand"
	"os"
	"strings"
	"time"
)

type BackendCoreCount struct {
	total     int
	frontend  int
	drive     int
	converged bool
}

type ClusterCreds struct {
	Username string
	Password string
}

type BackendCoreCounts map[string]BackendCoreCount

func shuffleSlice(slice []string) {
	rand.Seed(time.Now().UnixNano())
	rand.Shuffle(len(slice), func(i, j int) { slice[i], slice[j] = slice[j], slice[i] })
}

func getBackendCoreCounts() BackendCoreCounts {
	backendCoreCounts := BackendCoreCounts{
		"c2-standard-16": BackendCoreCount{total: 3, frontend: 1, drive: 1},
		"c2-standard-8":  BackendCoreCount{total: 3, frontend: 1, drive: 1},
	}
	return backendCoreCounts
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

func getToken(tokenId string) (token string, err error) {
	ctx := context.Background()
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

func GetJoinParams(project, zone, clusterName, usernameId, passwordId string) (bashScript string, err error) {
	role := "backend"
	ctx := context.Background()
	instanceClient, err := compute.NewInstancesRESTClient(ctx)
	if err != nil {
		log.Fatal().Err(err)
	}
	defer instanceClient.Close()

	clusterNameFilter := fmt.Sprintf("labels.cluster_name=%s", clusterName)
	listInstanceRequest := &computepb.ListInstancesRequest{
		Project: project,
		Zone:    zone,
		Filter:  &clusterNameFilter,
	}

	listInstanceIter := instanceClient.List(ctx, listInstanceRequest)

	var ips []string
	var instances []*computepb.Instance
	for {
		resp, err2 := listInstanceIter.Next()
		if err2 == iterator.Done {
			break
		}
		if err2 != nil {
			err = err2
			log.Error().Msgf("%s", err)
			return
		}
		ips = append(ips, *resp.NetworkInterfaces[0].NetworkIP)
		instances = append(instances, resp)
	}

	instanceTypeParts := strings.Split(*instances[0].MachineType, "/")
	instanceType := instanceTypeParts[len(instanceTypeParts)-1]
	shuffleSlice(ips)
	creds, err := getUsernameAndPassword(usernameId, passwordId)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}

	bashScriptTemplate := `
	#!/bin/bash

	set -ex

	export WEKA_USERNAME="%s"
	export WEKA_PASSWORD="%s"
	export WEKA_RUN_CREDS="-e WEKA_USERNAME=$WEKA_USERNAME -e WEKA_PASSWORD=$WEKA_PASSWORD"
	declare -a backend_ips=("%s" )

	random=$$
	echo $random
	for backend_ip in ${backend_ips[@]}; do
		if VERSION=$(curl -s -XPOST --data '{"jsonrpc":"2.0", "method":"client_query_backend", "id":"'$random'"}' $backend_ip:14000/api/v1 | sed  's/.*"software_release":"\([^"]*\)".*$/\1/g'); then
			if [[ "$VERSION" != "" ]]; then
				break
			fi
		fi
	done

	GATEWAYS=%s
	SUBNETS=%s
	SUBNETS_NUM=${#SUBNETS[@]}
	gws=""
	for (( i=1; i<$SUBNETS_NUM; i++ )); do
		ip=$(ifconfig eth$i | grep "inet " | awk '{ print $2}')
		while [ ! $ip ] ; do
			sleep 1
			ip=$(ifconfig eth$i | grep "inet " | awk '{ print $2}')
		done
		subnet=${SUBNETS[0]}
		mask=$(echo ${subnet##*/})
		gws="$gws --net eth$i/$ip/$mask/${GATEWAYS[$i]}"
	done
	echo $gws

	curl $backend_ip:14000/dist/v1/install | sh

	weka version get --from $backend_ip:14000 $VERSION --set-current
	weka version prepare $VERSION
	weka local stop && weka local rm --all -f
	weka local setup host --cores %d --frontend-dedicated-cores %d --drives-dedicated-cores %d --join-ips %s $gws`

	isReady := `
	while ! weka debug manhole -s 0 operational_status | grep '"is_ready": true' ; do
		sleep 1
	done
	echo Connected to cluster
	`

	addDrives := `
	host_id=$(weka local run $WEKA_RUN_CREDS manhole getServerInfo | grep hostIdValue: | awk '{print $2}')
	mkdir -p /opt/weka/tmp
	cat >/opt/weka/tmp/find_drives.py <<EOL
	import json
	import sys
	for d in json.load(sys.stdin)['disks']:
		if d['isRotational']: continue
		if d['type'] != 'DISK': continue
		if d['isMounted']: continue
		if d['model'] != 'nvme_card': continue
		print(d['devPath'])
	EOL
	devices=$(weka local run $WEKA_RUN_CREDS bash -ce 'wapi machine-query-info --info-types=DISKS -J | python3 /opt/weka/tmp/find_drives.py')
	for device in $devices; do
		weka local exec /weka/tools/weka_sign_drive $device
	done
	sleep 60
	weka cluster drive scan $host_id
	curl $INCREMENT_URL -H "Content-Type:application/json"  -d "{\"name\": \"$HOSTNAME\"}"
	curl $PROTECT_URL -H "Content-Type:application/json"  -d "{\"name\": \"$HOSTNAME\"}"
	curl $BUNCH_URL -H "Content-Type:application/json"  -d "{\"name\": \"$instance\"}"
	echo "completed successfully" > /tmp/weka_join_completion_validation
	`
	var cores, frontend, drive int
	if role == "backend" {
		backendCoreCounts := getBackendCoreCounts()
		instanceParams, ok := backendCoreCounts[instanceType]
		if !ok {
			err = errors.New(fmt.Sprintf("Unsupported instance type: %s", instanceType))
			return
		}
		cores = instanceParams.total
		frontend = instanceParams.frontend
		drive = instanceParams.drive
		if !instanceParams.converged {
			bashScriptTemplate += " --dedicate"
		}
		bashScriptTemplate += isReady + addDrives
	} else {
		bashScriptTemplate += isReady
		cores = 1
		frontend = 1
		drive = 0
	}

	bashScript = fmt.Sprintf(bashScriptTemplate, creds.Username, creds.Password, strings.Join(ips, "\" \""), os.Getenv("GATEWAYS"), os.Getenv("SUBNETS"), cores, frontend, drive, strings.Join(ips, ","))

	return
}

func GetClusterSizeInfo(project, collectionName, documentName string) (info map[string]interface{}) {
	log.Info().Msg("Retrieving desired group size from DB")

	ctx := context.Background()
	conf := &firebase.Config{ProjectID: project}
	app, err := firebase.NewApp(ctx, conf)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}

	client, err := app.Firestore(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}
	defer client.Close()
	doc := client.Collection(collectionName).Doc(documentName)
	res, err := doc.Get(ctx)
	if err != nil {
		log.Error().Msgf("%s", err)
		return
	}
	return res.Data()
}

func GetDeployScript(project, zone, clusterName, usernameId, passwordId, tokenId, collectionName, documentName, installUrl, clusterizeUrl, incrementUrl, protectUrl, bunchUrl, getInstancesUrl string) (bashScript string, err error) {
	clusterInfo := GetClusterSizeInfo(project, collectionName, documentName)
	instancesInterfaces := clusterInfo["instances"].([]interface{})
	instances := make([]string, len(instancesInterfaces))
	for i, v := range instancesInterfaces {
		instances[i] = v.(string)
	}
	initial_size := int(clusterInfo["initial_size"].(int64))

	installTemplate := `
	#!/bin/bash
	set -ex
	HOSTS_NUM=%d
	TOKEN=%s
	INSTALL_URL=%s
	INCREMENT_URL=%s
	PROTECT_URL=%s
	BUNCH_URL=%s
	CLUSTERIZE_URL=%s
	GET_INSTANCES_URL=%s

	# https://gist.github.com/fungusakafungus/1026804
	function retry {
		local retry_max=$1
		local retry_sleep=$2
		shift 2
		local count=$retry_max
		while [ $count -gt 0 ]; do
			"$@" && break
			count=$(($count - 1))
			sleep $retry_sleep
		done
		[ $count -eq 0 ] && {
			echo "Retry failed [$retry_max]: $@"
			return 1
		}
		return 0
	}
	
	retry 300 2 curl --fail --max-time 10 $INSTALL_URL | sh

	curl $INCREMENT_URL -H "Content-Type:application/json"  -d "{\"name\": \"$HOSTNAME\"}"
	curl $PROTECT_URL -H "Content-Type:application/json"  -d "{\"name\": \"$HOSTNAME\"}"

	eval instances=$(curl --silent $GET_INSTANCES_URL)
	if [ ${#instances[@]} == $HOSTS_NUM ] ; then
		curl $CLUSTERIZE_URL > /tmp/clusterize.sh
		chmod +x /tmp/clusterize.sh
		/tmp/clusterize.sh
		for instance in ${instances[@]}; do
			curl $BUNCH_URL -H "Content-Type:application/json"  -d "{\"name\": \"$instance\"}"
		done
	fi
	`

	token, err := getToken(tokenId)
	if err != nil {
		return
	}

	if len(instances) < initial_size {
		bashScript = fmt.Sprintf(installTemplate, initial_size, token, installUrl, incrementUrl, protectUrl, bunchUrl, clusterizeUrl, getInstancesUrl)
	} else {
		bashScript, err = GetJoinParams(project, zone, clusterName, usernameId, passwordId)
		if err != nil {
			return
		}
	}

	bashScript = dedent.Dedent(bashScript)
	return
}
