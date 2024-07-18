#!/bin/bash
set -ex

echo "$(date -u): cloud-init beginning"

if [ "${proxy_url}" ] ; then
	sudo sed -i "/distroverpkg=centos-release/a proxy=${proxy_url}" /etc/yum.conf
fi

if [ "${yum_repo_server}" ] ; then
	mkdir /tmp/yum.repos.d
	mv /etc/yum.repos.d/*.repo /tmp/yum.repos.d/

	cat >/etc/yum.repos.d/local.repo <<EOL
[localrepo-base]
name=RockyLinux Base
baseurl=${yum_repo_server}/baseos/
gpgcheck=0
enabled=1
[localrepo-appstream]
name=RockyLinux Base
baseurl=${yum_repo_server}/appstream/
gpgcheck=0
enabled=1
EOL
fi

os=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
if [[ "$os" = *"Rocky"* ]]; then
	sudo yum install -y bc
	sudo yum install -y perl-interpreter
	if [ "${yum_repo_server}" ]; then
		yum -y install ${yum_repo_server}/baseos/Packages/k/kernel-devel-4.18.0-513.24.1.el8_9.x86_64.rpm
		yum -y install wget
	else
		sudo curl https://dl.rockylinux.org/vault/rocky/8.9/Devel/x86_64/os/Packages/k/kernel-devel-4.18.0-513.24.1.el8_9.x86_64.rpm --output kernel-devel-4.18.0-513.24.1.el8_9.x86_64.rpm
		sudo rpm -i kernel-devel-4.18.0-513.24.1.el8_9.x86_64.rpm
	fi
fi

sudo yum install -y jq || (echo "Failed to install jq" && exit 1)

# make sure disk is attached
while ! [ "$(lsblk | grep ${disk_size}G | awk '{print $1}')" ] ; do
  echo "waiting for disk to be ready"
  sleep 5
done

gcloud config set functions/gen2 true

instance_name=$(curl -X GET http://metadata.google.internal/computeMetadata/v1/instance/name -H 'Metadata-Flavor: Google')

self_deleting() {
  err=$(tail -n 1 /tmp/weka_deploy.log)
  msg="deploy failed with error: $err, self-deleting instance..."
  echo $msg
  curl --retry 10 "${report_function_url}" --fail -H "Authorization:bearer $(gcloud auth print-identity-token)" -d "{\"hostname\": \"$instance_name\", \"protocol\": \"${protocol}\", \"type\": \"debug\", \"message\": \"$msg\"}"

	zone=$(curl -X GET http://metadata.google.internal/computeMetadata/v1/instance/zone -H 'Metadata-Flavor: Google')
	gcloud compute instances update $instance_name --no-deletion-protection --zone=$zone
	gcloud --quiet compute instances delete $instance_name --zone=$zone
}

echo "Generating weka deploy script..."
curl --retry 10 "${deploy_function_url}" --fail -H "Authorization:bearer $(gcloud auth print-identity-token)" -d "{\"name\": \"$instance_name\", \"protocol\": \"${protocol}\"}" > /tmp/deploy.sh
chmod +x /tmp/deploy.sh
echo "Running weka deploy script..."
(/tmp/deploy.sh 2>&1 | tee /tmp/weka_deploy.log) || self_deleting || shutdown -P
