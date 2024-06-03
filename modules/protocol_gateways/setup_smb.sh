echo "$(date -u): running smb script"

if [[ ${smbw_enabled} == true ]]; then
  wait_for_weka_fs || exit 1
  create_config_fs || exit 1
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

echo "$(date -u): SMB cluster ׳שד created successfully"
