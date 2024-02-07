echo "$(date -u): running smb script"
weka local ps

function wait_for_weka_fs(){
  filesystem_name="default"
  max_retries=30 # 30 * 10 = 5 minutes
  for (( i=0; i < max_retries; i++ )); do
    if [ "$(weka fs | grep -c $filesystem_name)" -ge 1 ]; then
      echo "$(date -u): weka filesystem $filesystem_name is up"
      break
    fi
    echo "$(date -u): waiting for weka filesystem $filesystem_name to be up"
    sleep 10
  done
  if (( i > max_retries )); then
      echo "$(date -u): timeout: weka filesystem $filesystem_name is not up after $max_retries attempts."
      return 1
  fi
}

# make sure weka cluster is already up
max_retries=60
for (( i=0; i < max_retries; i++ )); do
  if [ $(weka status | grep 'status: OK' | wc -l) -ge 1 ]; then
    echo "$(date -u): weka cluster is up"
    break
  fi
  echo "$(date -u): waiting for weka cluster to be up"
  sleep 30
done
if (( i > max_retries )); then
    echo "$(date -u): timeout: weka cluster is not up after $max_retries attempts."
    exit 1
fi

cluster_size="${gateways_number}"

current_mngmnt_ip=$(weka local resources | grep 'Management IPs' | awk '{print $NF}')
# get container id
for ((i=0; i<20; i++)); do
  container_id=$(weka cluster container | grep frontend0 | grep ${gateways_name} | grep $current_mngmnt_ip | grep UP | awk '{print $1}')
  if [ -n "$container_id" ]; then
      echo "$(date -u): frontend0 container id: $container_id"
      break
  fi
  echo "$(date -u): waiting for frontend0 container to be up"
  sleep 5
done

if [ -z "$container_id" ]; then
  echo "$(date -u): Failed to get the frontend0 container ID."
  exit 1
fi

# wait for all containers to be ready
max_retries=60
for (( retry=1; retry<=max_retries; retry++ )); do
    # get all UP gateway container ids
    all_container_ids=$(weka cluster container | grep frontend0 | grep ${gateways_name} | grep UP | awk '{print $1}')
    # if number of all_container_ids < cluster_size, do nothing
    all_container_ids_number=$(echo "$all_container_ids" | wc -l)
    if (( all_container_ids_number < cluster_size )); then
        echo "$(date -u): not all containers are ready - do retry $retry of $max_retries"
        sleep 20
    else
        echo "$(date -u): all containers are ready"
        break
    fi
done

if (( retry > max_retries )); then
    echo "$(date -u): timeout: not all containers are ready after $max_retries attempts."
    exit 1
fi

# wait for weka smb cluster to be ready in case it was created by another host
weka smb cluster wait

not_ready_hosts=$(weka smb cluster status | grep 'Not Ready' | wc -l)
all_hosts=$(weka smb cluster status | grep 'Host' | wc -l)

if (( all_hosts > 0 && not_ready_hosts == 0 && all_hosts == cluster_size )); then
    echo "$(date -u): SMB cluster is already created"
    weka smb cluster status
    exit 0
fi

if (( all_hosts > 0 && not_ready_hosts == 0 && all_hosts < cluster_size )); then
    echo "$(date -u): SMB cluster already exists, adding current container to it"

    weka smb cluster containers add --container-ids $container_id
    weka smb cluster wait
    weka smb cluster status
    exit 0
fi

echo "$(date -u): weka SMB cluster does not exist, creating it"
# get all protocol gateways fromtend container ids separated by comma
all_container_ids_str=$(echo "$all_container_ids" | tr '\n' ',' | sed 's/,$//')

sleep 30s
# if smbw_enabled is true, enable SMBW by adding --smbw flag
smbw_cmd_extention=""
if [[ ${smbw_enabled} == true ]]; then
    smbw_cmd_extention="--smbw --config-fs-name .config_fs"
fi

# new smbw config, where smbw is the default
smb_cmd_extention=""
if [[ ${smbw_enabled} == false ]]; then
    smb_cmd_extention="--smb"
fi

# run command with retry
function retry_command {
  retry_max=60
  retry_sleep=30
  count=$retry_max
  command=$1
  msg=$2


  while [ $count -gt 0 ]; do
      eval "$command" && break
      count=$(($count - 1))
      echo "Retrying $msg in $retry_sleep seconds..."
      sleep $retry_sleep
  done
  [ $count -eq 0 ] && {
      echo "$msg failed after $retry_max attempts"
      echo "$(date -u): $msg failed"
      return 1
  }
  return 0
}

sed -i "/$HOSTNAME/d" /etc/hosts
create_smb_cmd="weka smb cluster create ${cluster_name} ${domain_name} $smbw_cmd_extention --container-ids $all_container_ids_str || weka smb cluster create ${cluster_name} ${domain_name} .config_fs --container-ids $all_container_ids_str $smb_cmd_extention"
echo "running: $create_smb_cmd"
retry_command "$create_smb_cmd" "create smb cluster"

weka smb cluster wait

weka smb cluster status

echo "$(date -u): SMB cluster is created successfully"
