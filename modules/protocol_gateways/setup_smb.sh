echo "$(date -u): running smb script"

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

function retry_create_smb_cluster {
  retry_max=60
  retry_sleep=30
  count=$retry_max

  while [ $count -gt 0 ]; do
      # old smb config, where smb is the default
      weka smb cluster create ${cluster_name} ${domain_name} $smbw_cmd_extention --container-ids $all_container_ids_str && break
      # new smb config, where smbw is the default
      weka smb cluster create ${cluster_name} ${domain_name} .config_fs --container-ids $all_container_ids_str $smb_cmd_extention && break
      count=$(($count - 1))
      echo "Retrying create SMB cluster in $retry_sleep seconds..."
      sleep $retry_sleep
  done
  [ $count -eq 0 ] && {
      echo "create SMB cluster command failed after $retry_max attempts"
      echo "$(date -u): create SMB cluster failed"
      return 1
  }
  return 0
}

echo "$(date -u): Retrying create SMB cluster..."
sed -i "/$HOSTNAME/d" /etc/hosts

retry_create_smb_cluster

echo "$(date -u): Successfully create SMB cluster..."

weka smb cluster wait

weka smb cluster status

echo "$(date -u): SMB cluster was created successfully"
