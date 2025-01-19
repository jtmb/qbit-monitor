#!/bin/bash

# Variable to keep track of qBittorrent status
PREVIOUS_STATUS="unknown"

# Function to check if qBittorrent is running and send status notifications
check_qbittorrent_status() {
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$QBITTORRENT_HOST/api/v2/auth/login" \
        --data-urlencode "username=$QBITTORRENT_USERNAME" \
        --data-urlencode "password=$QBITTORRENT_PASSWORD" \
        --cookie-jar /tmp/cookie.txt)

    if [[ "$response" -eq 200 ]]; then
        response=$(curl -s -o /dev/null -w "%{http_code}" "$QBITTORRENT_HOST/api/v2/app/version" \
            --cookie /tmp/cookie.txt)

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
