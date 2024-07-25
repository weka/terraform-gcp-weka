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

apt update && apt install -y net-tools && apt install -y gcc-12 || true
