#!/bin/bash

set -ex

echo "$(date -u): cloud-init beginning"

# set apt private repo
if [[ "${yum_repo_server}" != "" ]]; then
  mv /etc/apt/sources.list /etc/apt/sources.list.bak
  echo "deb ${yum_repo_server} focal main restricted universe" > /etc/yum/sources.list
  echo "deb ${yum_repo_server} focal-updates main restricted" >> /etc/yum/sources.list
fi


# getNetStrForDpdk bash function definitiion
function getNetStrForDpdk() {
  i=$1
  j=$2
  gateways=$3
  subnets=$4
  net_option_name=$5

  if [ "$#" -lt 5 ]; then
      echo "'net_option_name' argument is not provided. Using default value: --net"
      net_option_name="--net "
  fi

  if [ -n "$gateways" ]; then #azure and gcp
    gateways=($gateways)
  fi

  net=" "
  for ((i; i<$j; i++)); do
    eth=eth$i
    subnet_inet=$(ifconfig $eth | grep 'inet ' | awk '{print $2}')
    if [ -z "$subnet_inet" ];then
      net=""
      break
    fi

    enp=$(ethtool -i $eth | grep bus-info | awk '{print $2}') #pci for gcp

    bits=$(ip -o -f inet addr show $eth | awk '{print $4}')
    IFS='/' read -ra netmask <<< "$bits"
    gateway=$${gateways[0]}
    net="$net $net_option_name$enp/$subnet_inet/$${netmask[1]}/$gateway"

	done
}

# https://gist.github.com/fungusakafungus/1026804
function retry {
  local retry_max=$1
  local retry_sleep=$2
  shift 2
  local count=$retry_max
  while [ $count -gt 0 ]; do
      "$@" && break
      count=$(($count - 1))
      echo "Retrying $* in $retry_sleep seconds..."
      sleep $retry_sleep
  done
  [ $count -eq 0 ] && {
      echo "Retry failed [$retry_max]: $*"
      echo "$(date -u): retry failed"
      return 1
  }
  return 0
}

# attach disk
sleep 30s

while ! [ "$(lsblk | grep ${disk_size}G | awk '{print $1}')" ] ; do
  echo "waiting for disk to be ready"
  sleep 5
done

wekaiosw_device=/dev/"$(lsblk | grep ${disk_size}G | awk '{print $1}')"

status=0
mkfs.ext4 -F -L wekaiosw $wekaiosw_device
mkdir -p /opt/weka 2>&1
mount $wekaiosw_device /opt/weka

echo "LABEL=wekaiosw /opt/weka ext4 defaults 0 2" >>/etc/fstab

# install weka
INSTALLATION_PATH="/tmp/weka"
mkdir -p $INSTALLATION_PATH
cd $INSTALLATION_PATH

echo "$(date -u): before weka agent installation"
yum -y update
yum -y install jq
# get token for secret manager (get-weka-io-token)
max_retries=12 # 12 * 10 = 2 minutes
for ((i=0; i<max_retries; i++)); do
  TOKEN=$(curl "https://secretmanager.googleapis.com/v1/${weka_token_id}/versions/1:access" --request "GET" --header "authorization: Bearer $(gcloud auth print-access-token)" --header "content-type: application/json" | jq -r ".payload.data" | base64 --decode)
  if [ "$TOKEN" != "null" ]; then
    break
  fi
  sleep 10
  echo "$(date -u): waiting for token secret to be available"
done

# install weka
if [[ "${install_weka_url}" == *.tar ]]; then
    wget -P $INSTALLATION_PATH "${install_weka_url}"
    IFS='/' read -ra tar_str <<< "\"${install_weka_url}\""
    pkg_name=$(cut -d'/' -f"$${#tar_str[@]}" <<< "${install_weka_url}")
    cd $INSTALLATION_PATH
    tar -xvf $pkg_name
    tar_folder=$(echo $pkg_name | sed 's/.tar//')
    cd $INSTALLATION_PATH/$tar_folder
    ./install.sh
  else
    retry 300 2 curl --fail --proxy "${proxy_url}" --max-time 10 "${install_weka_url}" | sh
fi

echo "$(date -u): weka agent installation complete"
