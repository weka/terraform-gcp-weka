#!/bin/bash
set -ex

if [[ "${yum_repository_baseos_url}" ]] ; then
    mkdir /tmp/yum.repos.d
    mv /etc/yum.repos.d/*.repo /tmp/yum.repos.d/

    cat >/etc/yum.repos.d/local.repo <<EOL
[localrepo-base]
name=RockyLinux BaseOs
baseurl=${yum_repository_baseos_url}
gpgcheck=0
enabled=1
module_hotfixes=1
[localrepo-appstream]
name=RockyLinux AppStream
baseurl=${yum_repository_appstream_url}
gpgcheck=0
enabled=1
module_hotfixes=1
EOL
fi

os=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
if [[ "$os" = *"Rocky"* ]]; then
    yum install -y kernel-devel-$(uname -r)
fi

apt update && apt install -y net-tools && apt install -y gcc-12 || true
