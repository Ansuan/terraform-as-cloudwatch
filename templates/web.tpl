#!/bin/bash
apt update
apt install apache2 libapache2-mod-php -y
service apache2 start
rm /var/www/html/index.html
curl -k https://raw.githubusercontent.com/simonebrunozzi/simplewebpage2/master/cpu-stress-test.php -o /var/www/html/index.php