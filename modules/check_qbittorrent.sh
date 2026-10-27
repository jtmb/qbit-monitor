#!/bin/bash

# Variable to keep track of qBittorrent status
PREVIOUS_STATUS="unknown"

# Function to check if qBittorrent is running and send status notifications
check_qbittorrent_status() {
    local response
    if login_to_qbittorrent; then
        response=$(qbit_api -sS -o /dev/null -w "%{http_code}" \
            "$QBITTORRENT_HOST/api/v2/app/version") || response=000

        if [[ "$response" -eq 200 ]]; then
            # Send notification if status changes to online
            if [[ "$PREVIOUS_STATUS" != "online" ]]; then
                send_discord_notification "qbittorrent_online"
                PREVIOUS_STATUS="online"
            fi
            return 0
        fi
    fi

    # Send notification if status changes to offline
    if [[ "$PREVIOUS_STATUS" != "offline" ]]; then
        send_discord_notification "qbittorrent_offline"
        PREVIOUS_STATUS="offline"
    fi
    return 1
}
