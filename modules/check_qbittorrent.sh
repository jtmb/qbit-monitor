#!/bin/bash

# Function to check if qBittorrent is running
check_qbittorrent_status() {
    # Attempt to log in to qBittorrent API to obtain a session cookie
    response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$QBITTORRENT_HOST/api/v2/auth/login" \
        --data-urlencode "username=$QBITTORRENT_USERNAME" \
        --data-urlencode "password=$QBITTORRENT_PASSWORD" \
        --cookie-jar /tmp/cookie.txt)

    if [[ "$response" -eq 200 ]]; then
        # Login successful, now check the API version
        response=$(curl -s -o /dev/null -w "%{http_code}" "$QBITTORRENT_HOST/api/v2/app/version" \
            --cookie /tmp/cookie.txt)

        if [[ "$response" -eq 200 ]]; then
            echo "qBittorrent API is accecible! Proceeding...."
            return 0
        else
            echo "Error: Unable to access qBittorrent API (HTTP Status: $response)." >&2
            return 1
        fi
    else
        echo "Error: qBittorrent authentication failed (HTTP Status: $response)." >&2
        return 1
    fi
}
