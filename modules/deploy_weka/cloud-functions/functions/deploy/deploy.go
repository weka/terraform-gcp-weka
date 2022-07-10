package deploy

import (
	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	"context"
	"errors"
	"fmt"
	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"github.com/weka/gcp-tf/modules/deploy_weka/cloud-functions/common"
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

func GetJoinParams(project, zone, instanceGroup, usernameId, passwordId, finalizeUrl string) (bashScript string, err error) {
	role := "backend"

	instances, err := common.GetInstances(project, zone, common.GetInstanceGroupInstanceNames(project, zone, instanceGroup))
	if err != nil {
		return
	}

	var ips []string
	for _, instance := range instances {
		ips = append(ips, *instance.NetworkInterfaces[0].NetworkIP)
	}

	if len(instances) == 0 {
		err = errors.New(fmt.Sprintf("No instances found for instance group %s, can't join", instanceGroup))
		return
	}

	instanceTypeParts := strings.Split(*instances[0].MachineType, "/")
	instanceType := instanceTypeParts[len(instanceTypeParts)-1]
	shuffleSlice(ips)
	creds, err := common.GetUsernameAndPassword(usernameId, passwordId)
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
	FINALIZE_URL=%s
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
	curl $FINALIZE_URL -H "Authorization:bearer $(gcloud auth print-identity-token)" -H "Content-Type:application/json"  -d "{\"name\": \"$HOSTNAME\"}"
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
		bashScriptTemplate += isReady + fmt.Sprintf(addDrives, finalizeUrl)
	} else {
		bashScriptTemplate += isReady
		cores = 1
		frontend = 1
		drive = 0
	}

	bashScript = fmt.Sprintf(bashScriptTemplate, creds.Username, creds.Password, strings.Join(ips, "\" \""), os.Getenv("GATEWAYS"), os.Getenv("SUBNETS"), cores, frontend, drive, strings.Join(ips, ","))

	return
}

func GetDeployScript(project, zone, instanceGroup, usernameId, passwordId, tokenId, bucket, installUrl, clusterizeUrl, finalizeUrl string) (bashScript string, err error) {
	state, err := common.GetClusterState(bucket)
	if err != nil {
		return
	}
	initialSize := state.InitialSize

	installTemplate := `
	#!/bin/bash
	set -ex
	HOSTS_NUM=%d
	TOKEN=%s
	INSTALL_URL=%s
	CLUSTERIZE_URL=%s

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

	curl $CLUSTERIZE_URL -H "Authorization:bearer $(gcloud auth print-identity-token)" -H "Content-Type:application/json"  -d "{\"name\": \"$HOSTNAME\"}" > /tmp/clusterize.sh
	chmod +x /tmp/clusterize.sh
	/tmp/clusterize.sh
	`

	token, err := getToken(tokenId)
	if err != nil {
		return
	}

	if !state.Clusterized {
		bashScript = fmt.Sprintf(installTemplate, initialSize, token, installUrl, clusterizeUrl)
	} else {
		bashScript, err = GetJoinParams(project, zone, instanceGroup, usernameId, passwordId, finalizeUrl)
		if err != nil {
			return
		}
	}

	bashScript = dedent.Dedent(bashScript)
	return
}
