#!/bin/sh

# Display Banner
if [ -z "$DISPLAYED_BANNER" ]; then
  cat << "EOF"
       _     _ _                         _         __                          
  __ _| |__ (_) |_      _ __   ___  _ __| |_      / _| ___  _ ____      ____ _ 
 / _` | '_ \| | __|____| '_ \ / _ \| '__| __|____| |_ / _ \| '__\ \ /\ / / _` |
| (_| | |_) | | ||_____| |_) | (_) | |  | ||_____|  _| (_) | |   \ V  V / (_| |
 \__, |_.__/|_|\__|    | .__/ \___/|_|   \__|    |_|  \___/|_|    \_/\_/ \__,_|
 _ _|_|_| | ___ _ __   |_|                                                     
| '__/ _` |/ _ \ '__|                                                          
| | | (_| |  __/ |                                                             
|_|  \__,_|\___|_|

Author: https://github.com/jtmb                                                                
EOF
echo ""
echo -e "qbit-port-forwarder is Running ✅"
echo ""

  # Set a flag so the banner doesn't show again
  DISPLAYED_BANNER=true
fi

# Default wait time between loops (in seconds)
wait_time=${WAIT_TIME:-10}

while true; do

  # Display run time
  date_time=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "|| $date_time ||"
  
  # Get the forwarded port
  tcpport=$(cat "${container_volumes_location}/gluetun/forwarded_port")
  echo "Glueten VPN port is set to $tcpport"

  # Login to qBittorrent and store the session cookie
  curl --cookie-jar /tmp/cookie.txt -i --header "Referer: http://${node}:8112" \
    --data "username=${ADMIN_USER}&password=${ADMIN_PASS}" \
    http://${node}:8112/api/v2/auth/login > /dev/null 2>&1

  # Get the current listen_port from qBittorrent preferences
  current_port=$(curl -s -b /tmp/cookie.txt "http://${node}:8112/api/v2/app/preferences" | jq -r '.listen_port')

  echo -e "Current Qbittorrent listen_port is $current_port "

  # Check if the port has changed
  if [ "$tcpport" != "$current_port" ]; then
    echo -e "Port has changed - Updating Qbittorrent listen_port to $tcpport 🚨"

    # Update the listen_port in qBittorrent preferences
    curl -s -b /tmp/cookie.txt "http://${node}:8112/api/v2/app/setPreferences" \
      -d "json={\"listen_port\": \"$tcpport\"}"

    echo -e "Qbittorrent listen_port updated to $tcpport ✔️"
  else
    echo -e "Port is unchanged. No update needed."
  fi

  echo -e "Waiting for $wait_time before next iteration..."
  sleep "$wait_time"
  echo "------------------------------------------------------------------------------------"
  echo ""
done