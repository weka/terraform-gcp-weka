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
sslverify=0
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
type=rpm-md
username=oauth2accesstoken
password=TOKEN
[localrepo-appstream]
name=RockyLinux AppStream
baseurl=${yum_repository_appstream_url}
gpgcheck=0
enabled=1
module_hotfixes=1
sslverify=0
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
type=rpm-md
username=oauth2accesstoken
password=TOKEN
EOL
sed -i "s|^password=.*|password=$(gcloud auth print-access-token)|" /etc/yum.repos.d/local.repo
CRON_JOB="* * * * * gcloud auth print-access-token | sed -i \"s|^password=.*|password=\$(gcloud auth print-access-token)|\" /etc/yum.repos.d/local.repo"
(crontab -l 2>/dev/null | grep -Fq "$CRON_JOB") || (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
fi



os=$(awk -F= '/^NAME/{print $2}' /etc/os-release)
if [[ "$os" = *"Rocky"* ]]; then
    # Use direct Rocky Linux baseurl to avoid mirror sync issues when not using custom repos
    if [ -z "${yum_repository_baseos_url}" ]; then
        rocky_version=$(awk -F= '/^VERSION_ID/{print $2}' /etc/os-release | tr -d '"')
        sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/Rocky-*.repo
        sed -i "s|^#baseurl=http://dl.rockylinux.org/\$contentdir/\$releasever|baseurl=https://dl.rockylinux.org/pub/rocky/$rocky_version|g" /etc/yum.repos.d/Rocky-*.repo
        yum clean all
    fi
    yum install -y kernel-devel-$(uname -r)
fi

apt update && apt install -y net-tools && apt install -y gcc-12 || true
