yum install -y httpd nginx wget
yum install -y epel-release
yum install -y createrepo yum-utils

mkdir /var/www/html/{base,centosplus,extras,updates}
reposync -g -l -d -m --repoid=base --newest-only --download-metadata --download_path=/var/www/html/
reposync -g -l -d -m --repoid=centosplus --newest-only --download-metadata --download_path=/var/www/html/
reposync -g -l -d -m --repoid=extras --newest-only --download-metadata --download_path=/var/www/html/
reposync -g -l -d -m --repoid=updates --newest-only --download-metadata --download_path=/var/www/html/

cd /var/www/html/updates/Packages
wget https://ftp.jaist.ac.jp/pub/Linux/CentOS/7/updates/x86_64/Packages/kernel-devel-3.10.0-1160.66.1.el7.x86_64.rpm
cd ~
createrepo  /var/www/html/

firewall-cmd --zone=public --permanent --add-service=http
firewall-cmd --zone=public --permanent --add-service=https
firewall-cmd --reload

cat <<EOT >> /etc/nginx/conf.d/repos.conf
server {
        listen   80;
        server_name  weka.yum.repo;	#change  test.lab to your real domain
        root   /var/www/html;
        location / {
                index  index.php index.html index.htm;
                autoindex on;	#enable listing of directory index
        }
}
EOT

systemctl start nginx
systemctl enable nginx
systemctl status nginx
