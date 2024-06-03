echo "$(date -u): running validation for setting protocol script"

weka local ps

filesystem_name="default"
function wait_for_weka_fs(){
  max_retries=30 # 30 * 10 = 5 minutes
  for (( i=0; i < max_retries; i++ )); do
    if [[ "$(weka fs | grep -c $filesystem_name)" -ge 1 ]]; then
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

function create_config_fs(){
  config_filesystem_name=".config_fs"
  size="10GB"

  if [ "$(weka fs | grep -c $config_filesystem_name)" -ge 1 ]; then
    echo "$(date -u): weka filesystem $config_filesystem_name exists"
    return 0
  fi

  echo "$(date -u): trying to create filesystem $config_filesystem_name"
  output=$(weka fs create $config_filesystem_name default $size 2>&1)
  # possiible outputs:
  # FSId: 1 (means success)
  # error: The given filesystem ".config_fs" already exists.
  # error: Not enough available drive capacity for filesystem. requested "10.00 GB", but only "0 B" are free
  if [ $? -eq 0 ]; then
    echo "$(date -u): weka filesystem $config_filesystem_name is created"
    return 0
  fi

  if [[ $output == *"already exists"* ]]; then
    echo "$(date -u): weka filesystem $config_filesystem_name already exists"
    break
  elif [[ $output == *"Not enough available drive capacity for filesystem"* ]]; then
    err_msg="Not enough available drive capacity for filesystem $config_filesystem_name for size $size"
    echo "$(date -u): $err_msg"
    return 1
  else
    echo "$(date -u): output: $output"
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

echo "$(date -u): Done running validation"
