#!/bin/bash

set -ex

echo "$(date -u): cloud-init beginning"

# set apt private repo
if [ "${yum_repo_server}" ] ; then
    mkdir /tmp/yum.repos.d
    mv /etc/yum.repos.d/*.repo /tmp/yum.repos.d/

    cat >/etc/yum.repos.d/local.repo <<EOL
[local]
name=Centos Base
baseurl=${yum_repo_server}
enabled=1
gpgcheck=0
EOL
fi

os=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
if [[ "$os" = *"Rocky"* ]]; then
		sudo yum install -y perl-interpreter
		sudo curl https://dl.rockylinux.org/vault/rocky/8.9/Devel/x86_64/os/Packages/k/kernel-devel-4.18.0-513.24.1.el8_9.x86_64.rpm --output kernel-devel-4.18.0-513.24.1.el8_9.x86_64.rpm
		sudo rpm -i kernel-devel-4.18.0-513.24.1.el8_9.x86_64.rpm
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
yum -y install jq
# get token for secret manager (get-weka-io-token)
max_retries=12 # 12 * 10 = 2 minutes
if [[ ${weka_token_id} != "NONE" ]]; then
  for ((i=0; i<max_retries; i++)); do
    TOKEN=$(curl "https://secretmanager.googleapis.com/v1/${weka_token_id}/versions/1:access" --request "GET" --header "authorization: Bearer $(gcloud auth print-access-token)" --header "content-type: application/json" | jq -r ".payload.data" | base64 --decode)
    if [ "$TOKEN" != "null" ]; then
      break
    fi
    sleep 10
    echo "$(date -u): waiting for token secret to be available"
  done
fi

# install weka
if [[ "${install_weka_url}" == *.tar ]]; then
    gsutil cp "${install_weka_url}" $INSTALLATION_PATH
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
