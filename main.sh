#!/bin/bash

# Configuration vars default
    # QBITTORRENT_HOST="http://192.168.0.x:8112"
    # QBITTORRENT_USERNAME="admin"
    # QBITTORRENT_PASSWORD="admin1234"
    # DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/xxxx"
    # CHECK_INTERVAL_TORRENT_MONITORING=10s
    # CHECK_INTERVAL_FORWARDED_PORT=1h
    # PORT_FORWARD_FILE=/mnt/gluetun/forwarded_port

# Set mandatory VARs
NOTIFIED_FILE="state/notified_torrents.txt"

# Source modules
source modules/banner.sh
source modules/common.sh
source modules/check_qbittorrent.sh
source modules/check_new.sh
source modules/check_completed.sh
source modules/check_metadata_stuck.sh
source modules/send_discord_notification.sh 
source modules/qbit-port-forwarder.sh

# Check mandatory environment variables
check_var "QBITTORRENT_HOST"
check_var "QBITTORRENT_USERNAME"
check_var "QBITTORRENT_PASSWORD"
check_var "DISCORD_WEBHOOK_URL"
check_var "CHECK_INTERVAL_TORRENT_MONITORING"
check_var "CHECK_INTERVAL_FORWARDED_PORT"
check_var "NOTIFIED_FILE"

# Check if qBittorrent is up before proceeding
check_qbittorrent_status
if [ $? -ne 0 ]; then
    echo "qBittorrent is not accessible. Exiting..." >&2
    exit 1
fi

# Initialize notified file
if [[ ! -f "$NOTIFIED_FILE" ]]; then
    touch "$NOTIFIED_FILE"
fi

# Login to qBittorrent
login_to_qbittorrent

# Start port forward monitoring in the background
monitor_qbittorrent_port &

# Main loop
while true; do
    torrents=$(get_torrents)
    check_new_torrents "$torrents" "$NOTIFIED_FILE"
    check_completed_torrents "$torrents" "$NOTIFIED_FILE"
    check_metadata_stuck_torrents "$torrents" "$NOTIFIED_FILE"
    echo -e "Torrents Validated. Waiting for $CHECK_INTERVAL_TORRENT_MONITORING before running again ..."
    sleep "$CHECK_INTERVAL_TORRENT_MONITORING"
done
