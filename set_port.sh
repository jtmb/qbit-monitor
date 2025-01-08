#!/bin/sh
echo "Contents of ${container_volumes_location}/gluetun/forwarded_port:"
cat ${container_volumes_location}/gluetun/forwarded_port
tcpport=$(cat ${container_volumes_location}/gluetun/forwarded_port)
echo "tcpport is set to $tcpport"
echo "Setting listen_port to $tcpport"
curl --cookie-jar /tmp/cookie.txt -i --header "Referer: http://${node}:8112" --data "username=${ADMIN_USER}&password=${ADMIN_PASS}" http://${node}:8112/api/v2/auth/login
curl -s -b /tmp/cookie.txt "http://${node}:8112/api/v2/app/setPreferences" -d "json={\"listen_port\": \"$tcpport\"}"
