#!/bin/sh

# Default wait time between loops (in seconds)
wait_time=${WAIT_TIME:-10}

while true; do
  echo "Contents of ${container_volumes_location}/gluetun/forwarded_port:"
  cat "${container_volumes_location}/gluetun/forwarded_port"
  
  tcpport=$(cat "${container_volumes_location}/gluetun/forwarded_port")
  echo "tcpport is set to $tcpport"
  echo "Setting listen_port to $tcpport"
  
  curl --cookie-jar /tmp/cookie.txt -i --header "Referer: http://${node}:8112" \
    --data "username=${ADMIN_USER}&password=${ADMIN_PASS}" \
    http://${node}:8112/api/v2/auth/login
  
  curl -s -b /tmp/cookie.txt "http://${node}:8112/api/v2/app/setPreferences" \
    -d "json={\"listen_port\": \"$tcpport\"}"
  
  echo "Waiting for $wait_time before next iteration..."
  sleep "$wait_time"
done
