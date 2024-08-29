#!/bin/bash
set -ex

if [[ "${yum_repo_server}" ]] ; then
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
    if [[ "${yum_repo_server}" ]]; then
			yum -y install ${yum_repo_server}/baseos/Packages/k/kernel-devel-4.18.0-513.24.1.el8_9.x86_64.rpm
			yum -y install wget
    else
      sudo curl https://dl.rockylinux.org/vault/rocky/8.9/Devel/x86_64/os/Packages/k/kernel-devel-4.18.0-513.24.1.el8_9.x86_64.rpm --output kernel-devel-4.18.0-513.24.1.el8_9.x86_64.rpm
      sudo rpm -i kernel-devel-4.18.0-513.24.1.el8_9.x86_64.rpm
    fi
fi

apt update && apt install -y net-tools && apt install -y gcc-12 || true
