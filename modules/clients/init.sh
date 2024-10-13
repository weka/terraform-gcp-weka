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
    if [[ ! $(rpm -qa | grep kernel-devel) ]]; then
      if [[ "${yum_repo_server}" ]]; then
          yum install -y ${yum_repo_server}/baseos/Packages/k/kernel-devel-$(uname -r).rpm
      else
          yum install -y kernel-devel-$(uname -r)
      fi
    fi
fi

apt update && apt install -y net-tools && apt install -y gcc-12 || true
