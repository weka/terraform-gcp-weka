echo "$(date -u): before weka agent installation"

INSTALLATION_PATH="/tmp/weka"
mkdir -p $INSTALLATION_PATH
cd $INSTALLATION_PATH


# install weka using backend lb ip
function retry_weka_install {
  retry_max=60
  retry_sleep=45
  count=$retry_max

  while [ $count -gt 0 ]; do
      curl --fail -o install_script.sh ${backend_lb_ip}:14000/dist/v1/install && break
      count=$(($count - 1))
      echo "Retrying weka install from ${backend_lb_ip} in $retry_sleep seconds..."
      sleep $retry_sleep
  done
  [ $count -eq 0 ] && {
      echo "weka install failed after $retry_max attempts"
      echo "$(date -u): weka install failed"
      return 1
  }
  chmod +x install_script.sh && ./install_script.sh
  return 0
}

retry_weka_install

echo "$(date -u): weka agent installation complete"

FILESYSTEM_NAME=default # replace with a different filesystem at need
MOUNT_POINT=/mnt/weka # replace with a different mount point at need
mkdir -p $MOUNT_POINT

weka local stop && weka local rm -f --all

gateways="${all_gateways}"
subnets="${all_subnets}"
FRONTEND_CONTAINER_CORES_NUM="${frontend_container_cores_num}"
NICS_NUM=$((FRONTEND_CONTAINER_CORES_NUM+1))

first_interface=$(ip -o link show | awk -F ': ' '!/docker0/ && !/^lo/ {print $2}' | sort | head -n 1)
interface_str=$(echo $first_interface | awk '{gsub(/[0-9]/,"",$1); print $1}')
first_interface_number=$(echo $first_interface | awk '{gsub(/[^0-9]/,"",$1); print $1}')
first_interface_ip=$(ip addr show $first_interface | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

function getNetStrForDpdk {
		i=$1
		j=$2
		gateways=$3
		index=1
		if [ -n "$gateways" ]; then #azure and gcp
			gateways=($gateways)
		fi

		net=""
		for ((i; i<$j; i++)); do
  			interface=$interface_str$i
  			subnet_inet=$(ifconfig $interface | grep 'inet ' | awk '{print $2}')
  			while [ -z $subnet_inet ]; do
  			  echo "waiting for $interface to get inet"
  				sleep 10
  				subnet_inet=$(ifconfig $interface | grep 'inet ' | awk '{print $2}')
  			done
  			enp=$(ls -l /sys/class/net/$interface/ | grep lower | awk -F"_" '{print $2}' | awk '{print $1}') #for azure
  			if [ -z $enp ];then
  				enp=$(ethtool -i $interface | grep bus-info | awk '{print $2}') #pci for gcp
  			fi
  			bits=$(ip -o -f inet addr show $interface | awk '{print $4}')
  			IFS='/' read -ra netmask <<< "$bits"

  			gateway=$${gateways[$index]}
  			net="$net -o net=$enp/$subnet_inet/$${netmask[1]}/$gateway"
  			index=$(($index+1))
  	done
}

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

mount_command="mount -t wekafs -o net=udp ${backend_lb_ip}/$FILESYSTEM_NAME $MOUNT_POINT"
if [[ ${clients_use_dpdk} == true ]]; then
  mount_dpdk_base_memory_mb=""
  if [ ${dpdk_base_memory_mb} -gt 0 ]; then
      mount_dpdk_base_memory_mb="-o dpdk_base_memory_mb=${dpdk_base_memory_mb}"
  fi
  getNetStrForDpdk $(($first_interface_number+1)) $(($NICS_NUM+$first_interface_number)) "$gateways" "$subnets"
  mount_command="mount -t wekafs $net -o num_cores=$FRONTEND_CONTAINER_CORES_NUM -o mgmt_ip=$first_interface_ip ${backend_lb_ip}/$FILESYSTEM_NAME $MOUNT_POINT $mount_dpdk_base_memory_mb"
fi

retry 60 45 $mount_command
echo "$(date -u): wekafs mount complete"

rm -rf $INSTALLATION_PATH
echo "$(date -u): client setup complete"
