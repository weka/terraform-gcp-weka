package join

import (
	compute "cloud.google.com/go/compute/apiv1"
	secretmanager "cloud.google.com/go/secretmanager/apiv1"
	"context"
	"errors"
	"fmt"
	"github.com/lithammer/dedent"
	"github.com/rs/zerolog/log"
	"google.golang.org/api/iterator"
	computepb "google.golang.org/genproto/googleapis/cloud/compute/v1"
	secretmanagerpb "google.golang.org/genproto/googleapis/cloud/secretmanager/v1"
	"math/rand"
	"net/http"
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
	}
	return backendCoreCounts
}

func getUsernameAndPassword() (clusterCreds ClusterCreds, err error) {
	ctx := context.Background()
	client, err := secretmanager.NewClient(ctx)
	if err != nil {
		return
	}
	defer client.Close()

	res, err := client.AccessSecretVersion(ctx, &secretmanagerpb.AccessSecretVersionRequest{Name: "projects/896245720241/secrets/weka_username/versions/1"})
	if err != nil {
		return
	}
	clusterCreds.Username = string(res.Payload.Data)
	res, err = client.AccessSecretVersion(ctx, &secretmanagerpb.AccessSecretVersionRequest{Name: "projects/896245720241/secrets/weka_password/versions/1"})
	if err != nil {
		return
	}
	clusterCreds.Password = string(res.Payload.Data)
	return
}

func GetJoinParams(project, zone, clusterName string) (bashScript string, err error) {
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
	creds, err := getUsernameAndPassword()
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
		ip=$(ifconfig eth$i | grep -m1 inet | awk '{ print $2}')
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

	bashScript = fmt.Sprintf(dedent.Dedent(bashScriptTemplate), creds.Username, creds.Password, strings.Join(ips, "\" \""), os.Getenv("GATEWAYS"), os.Getenv("SUBNETS"), cores, frontend, drive, strings.Join(ips, ","))

	return
}

func Join(w http.ResponseWriter, r *http.Request) {
	project := os.Getenv("PROJECT")
	zone := os.Getenv("ZONE")
	clusterName := os.Getenv("CLUSTER_NAME")

	fmt.Println("Getting join params")
	bashScript, err := GetJoinParams(project, zone, clusterName)
	if err != nil {
		fmt.Fprintf(w, "%s", err)
	} else {
		fmt.Fprintf(w, bashScript)
	}
}
