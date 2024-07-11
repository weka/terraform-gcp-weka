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

all_subnets=(${subnets})
echo "subnets: $${all_subnets[@]}"

cat >>/usr/sbin/remove-routes.sh <<EOF
#!/bin/bash
set -ex
EOF
for(( i=1; i<${nics_num}; i++ )); do
  subnet=$${all_subnets[$i]}
  cat >>/usr/sbin/remove-routes.sh <<EOF
while ! ip route | grep eth$i; do
  ip route
  sleep 5
done
while ip route | grep "$subnet" | grep "eth$i"; do
  echo "Removing route for $subnet on eth$i"
  ip route del $subnet dev eth$i
done
EOF
done

chmod +x /usr/sbin/remove-routes.sh

cat >/etc/systemd/system/remove-routes.service <<EOF
[Unit]
Description=Remove specific routes
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/bin/bash /usr/sbin/remove-routes.sh

[Install]
WantedBy=multi-user.target
EOF

ip route # show routes before removing
systemctl daemon-reload
systemctl enable remove-routes.service
systemctl start remove-routes.service
systemctl status remove-routes.service || true # show status of remove-routes.service
ip route # show routes after removing
