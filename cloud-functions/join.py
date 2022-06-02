from googleapiclient.discovery import build
from dataclasses import dataclass
from typing import Dict
from flask import escape
import functions_framework


@dataclass
class BackendCoreCount:
    total: int
    frontend: int
    drive: int
    converged: bool = False


def get_backend_core_counts() -> Dict[str, BackendCoreCount]:
    return {
        "c2-standard-16": BackendCoreCount(total=3, frontend=1, drive=1)
    }


service = build('compute', 'v1')


def get_join_params(project: str, zone: str, username: str, password: str):
    res = service.instances().list(project=project, zone=zone).execute()
    backend_ips = [item['networkInterfaces'][0]['networkIP'] for item in res['items']]
    instance_type = res['items'][0]['machineType'].split('/')[-1]

    bash_script_template = """
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

curl $backend_ip:14000/dist/v1/install | sh

weka version get --from $backend_ip:14000 $VERSION --set-current
weka version prepare $VERSION
weka local stop && weka local rm --all -f
weka local setup host --cores %d --frontend-dedicated-cores %d --drives-dedicated-cores %d --join-ips %s
"""

    is_ready = """
while ! weka debug manhole -s 0 operational_status | grep '"is_ready": true' ; do
    sleep 1
done
echo Connected to cluster
"""

    add_drives = """
host_id=$(weka local run $WEKA_RUN_CREDS manhole getServerInfo | grep hostIdValue: | awk '{print $2}')
mkdir -p /opt/weka/tmp
cat >/opt/weka/tmp/find_drives.py <<EOL
import json
import sys
for d in json.load(sys.stdin)['disks']:
    if d['isRotational']: continue
    if d['type'] != 'DISK': continue
    if d['isMounted']: continue
    if d['model'] != 'Amazon EC2 NVMe Instance Storage': continue
    print(d['devPath'])
EOL
devices=$(weka local run $WEKA_RUN_CREDS bash -ce 'wapi machine-query-info --info-types=DISKS -J | python3 /opt/weka/tmp/find_drives.py')
for device in $devices; do
    weka cluster drive add $host_id $device
done
"""
    instance_params = get_backend_core_counts()[instance_type]

    if not instance_params.converged:
        bash_script_template += " --dedicate"

    bash_script_template += is_ready + add_drives

    return bash_script_template % (
        username,
        password,
        " ".join(backend_ips),
        instance_params.total,
        instance_params.frontend,
        instance_params.drive,
        " ".join(backend_ips)
    )


def get_param(request_json, request_args, param_name):
    if request_json and param_name in request_json:
        return request_json[param_name]

    if request_args and param_name in request_args:
        return request_args[param_name]

    return ''


@functions_framework.http
def join(request):
    request_json = request.get_json(silent=True)
    request_args = request.args
    print("request json:", request_json)
    print("request args:", request_args)

    project = get_param(request_json, request_args, 'project')
    if not project:
        return ''

    zone = get_param(request_json, request_args, 'zone')
    if not zone:
        return ''

    username = get_param(request_json, request_args, 'username')
    if not username:
        return ''

    password = get_param(request_json, request_args, 'password')
    if not password:
        return ''

    return get_join_params(project=project, zone=zone, username=username, password=password)
