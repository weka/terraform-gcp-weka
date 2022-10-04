import subprocess
from typing import Dict, Iterable

from google.cloud import compute_v1
from logging import getLogger

_logger = getLogger()


def get_cluster_vms_names(project, zone):
    instance_group_client = compute_v1.InstanceGroupsClient()
    instance_group_instances = instance_group_client.list_instances(project=project, zone=zone,
                                                                    instance_group="weka-poc-instance-group")
    return [instance.instance.split('/')[-1] for instance in instance_group_instances]


def get_cluster_ips(project, zone):
    request = compute_v1.ListInstancesRequest()
    request.project = project
    request.zone = zone
    request.filter = ' OR '.join([f"name={name}" for name in get_cluster_vms_names()])

    instance_client = compute_v1.InstancesClient()
    instances = instance_client.list(request=request)

    return [instance.network_interfaces[0].access_configs[0].nat_i_p for instance in instances]


def run_remote_command(project, zone, host, command):
    cmd = f'gcloud compute ssh --project {project} --zone {zone} {host}'
    _logger.info(f'{host}: {cmd} --command "{command}"')
    return subprocess.Popen(cmd.split(' ') + ['--command', command], shell=False, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)


def copy_file_to_remote_vm(project, zone, host, filename):
    cmd = f'gcloud compute scp --project {project} --zone {zone} {filename} {host}:~'
    _logger.info(f'{host}: {cmd}')
    return subprocess.Popen(cmd.split(' '), shell=False, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def test_load():
    project = 'wekaio-rnd'
    zone = "europe-west1-b"
    hosts = get_cluster_vms_names(project=project, zone=zone)
    copy_file_to_remote_vm(project, zone, hosts[0], 'test/test.sh')
    res = run_remote_command(project, zone, hosts[0], './test.sh')
    _logger.info(res.stdout.read())
