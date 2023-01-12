#!/bin/bash
apt install -y nginx-light php-fpm php-pear php-cgi php-common php-mbstring php-zip php-net-socket php-gd php-xml-util php-mysql php-bcmath unzip
mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf
mv /etc/nginx/sites-available/default /etc/nginx/sites-available/default
ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
service nginx restart
chown -R www-data:www-data /var/www
apt install -y logrotate
echo "php_admin_flag[expose_php] = off" >> /etc/php/7.4/fpm/php-fpm.conf
service php7.4-fpm restart && service nginx restart