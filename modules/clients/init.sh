#!/bin/bash
set -ex

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

apt update && apt install -y net-tools && apt install -y gcc-12 || true
