weka local ps

function create_interface_group() {
  if weka nfs interface-group | grep ${interface_group_name}; then
    echo "$(date -u): interface group ${interface_group_name} already exists"
    return
  fi
  echo "$(date -u): creating interface group"
  weka nfs interface-group add ${interface_group_name} NFS
  echo "$(date -u): interface group ${interface_group_name} created"
}

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

function create_client_group() {
  if weka nfs client-group | grep ${client_group_name}; then
    echo "$(date -u): client group ${client_group_name} already exists"
    return
  fi
  echo "$(date -u): creating client group"
  weka nfs client-group add ${client_group_name}
  weka nfs rules add dns ${client_group_name} *
  wait_for_weka_fs || return 1
  weka nfs permission add default ${client_group_name}
  echo "$(date -u): client group ${client_group_name} created"
}

# make sure weka cluster is already up
max_retries=60 # 60 * 30 = 30 minutes
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

# create interface group if not exists
create_interface_group || true

current_mngmnt_ip=$(weka local resources | grep 'Management IPs' | awk '{print $NF}')
# get container id
max_retries=12 # 12 * 10 = 2 minutes
for ((i=0; i<max_retries; i++)); do
  container_id=$(weka cluster container | grep frontend0 | grep ${gateways_name} | grep $current_mngmnt_ip | grep UP | awk '{print $1}')
  if [ -n "$container_id" ]; then
      echo "$(date -u): frontend0 container id: $container_id"
      break
  fi
  echo "$(date -u): waiting for frontend0 container to be up"
  sleep 10
done

if [ -z "$container_id" ]; then
  echo "$(date -u): Failed to get the frontend0 container ID."
  exit 1
fi

# get device to use
port=$(ip -o -f inet addr show | grep "$current_mngmnt_ip/"| awk '{print $2}')

weka nfs interface-group port add ${interface_group_name} $container_id $port
# show interface group
weka nfs interface-group

# create client group if not exists and add rules / premissions
create_client_group || true

weka nfs client-group

echo "$(date -u): NFS setup complete"
