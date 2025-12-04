#!/bin/bash

INAME=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
IPADDR=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat <<EOF > /var/www/html/healthcheck.html
WEB Server: $INAME<br>
IP: $IPADDR<br>
AZ: $AZ<br>
EOF