#!/bin/bash

# Function to monitor and update qBittorrent port
monitor_qbittorrent_port() {
  # Default wait time between loops (in seconds)
  CHECK_INTERVAL=${CHECK_INTERVAL:-10}

  while true; do
    # Get the forwarded port
    tcpport=$(cat "${PORT_FORWARD_FILE}")
    echo "Glueten VPN port is set to $tcpport"

    # Login to qBittorrent and store the session cookie
    response=$(curl -si -X POST "${QBITTORRENT_HOST}/api/v2/auth/login" \
      --data-urlencode "username=${QBITTORRENT_USERNAME}" \
      --data-urlencode "password=${QBITTORRENT_PASSWORD}" \
      --cookie-jar /tmp/cookie.txt)
    if echo "$response" | grep -q "HTTP/1.1 200 OK"; then
      echo "Login successful"
    else
      echo "Login failed"
      continue
    fi

    # Get the current listen_port from qBittorrent preferences
    response=$(curl -s -b /tmp/cookie.txt "${QBITTORRENT_HOST}/api/v2/app/preferences")
    if [ -z "$response" ]; then
      echo "Error: Empty response from qBittorrent API"
      continue
    fi
    current_port=$(echo "$response" | jq -r '.listen_port')
    if [ "$current_port" == "null" ]; then
      echo "Error: 'listen_port' not found in API response"
      continue
    fi

    echo -e "Current Qbittorrent listen_port is $current_port"

    # Check if the port has changed
    if [ "$tcpport" != "$current_port" ]; then
      echo -e "Port has changed - Updating Qbittorrent listen_port to $tcpport 🚨"

      # Update the listen_port in qBittorrent preferences
      curl -s -b /tmp/cookie.txt "${QBITTORRENT_HOST}/api/v2/app/setPreferences" \
        -d "json={\"listen_port\": \"$tcpport\"}"

      echo -e "Qbittorrent listen_port updated to $tcpport ✔️"
      
      # Call the function to send a Discord notification
      send_discord_notification "port_updated" "$tcpport"
    else
      echo -e "Port is unchanged. No update needed."
    fi

    echo -e "Waiting for $CHECK_INTERVAL_FORWARDED_PORT before next port check iteration..."
    sleep "$CHECK_INTERVAL_FORWARDED_PORT"
    echo "------------------------------------------------------------------------------------"
    echo ""
  done
}

# Export the function for use in other scripts
export -f monitor_qbittorrent_port
