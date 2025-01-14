#!/bin/bash

# Function to check if a variable is set
check_var() {
    local var_name="$1"
    local var_value="${!var_name}"
    if [ -z "$var_value" ]; then
        echo "Error: MANDATORY VAR '$var_name' is not set." >&2
        echo -e "USER VARS SET:"
        echo -e "QBITTORRENT_HOST: $QBITTORRENT_HOST"
        echo -e "QBITTORRENT_USERNAME: $QBITTORRENT_USERNAME"
        echo -e "QBITTORRENT_PASSWORD: $QBITTORRENT_PASSWORD"
        echo -e "CHECK_INTERVAL_TORRENT_MONITORING: $CHECK_INTERVAL_TORRENT_MONITORING"
        echo -e "CHECK_INTERVAL_FORWARDED_PORT: $CHECK_INTERVAL_FORWARDED_PORT"
        echo -e "PORT_FORWARD_FILE: $PORT_FORWARD_FILE"
        echo -e "DISCORD_WEBHOOK_URL: $DISCORD_WEBHOOK_URL"
        echo ""
        exit 1
    fi
}

# Function to send a Discord notification
send_discord_notification() {
    local message="$1"
    curl -X POST -H "Content-Type: application/json" \
        -d "{\"content\": \"$message\"}" \
        "$DISCORD_WEBHOOK_URL"
}

# Login to qBittorrent API and get the cookie
login_to_qbittorrent() {
    COOKIE=$(curl -si -X POST "$QBITTORRENT_HOST/api/v2/auth/login" \
        --data-urlencode "username=$QBITTORRENT_USERNAME" \
        --data-urlencode "password=$QBITTORRENT_PASSWORD" | \
        grep -oP 'SID=.*?;' | tr -d ';')
}

# Get torrents from qBittorrent
get_torrents() {
    curl -s -X GET "$QBITTORRENT_HOST/api/v2/torrents/info" \
        -H "Cookie: $COOKIE"
}