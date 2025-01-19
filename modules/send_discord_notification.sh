#!/bin/bash

# Function to send Discord notifications
send_discord_notification() {
    local message_type="$1"
    local additional_data="$2"
    local title description color fields
    TZ=$(date +%Z)

    # Define the title and description for each notification type
    case "$message_type" in
        "new")
            if [[ "${NEW_DOWNLOAD_NOTIFICATION}" == "off" ]]; then
                echo "New torrent notifications are disabled."
                return
            fi
            title="QbitMonitor: New Torrent Added"
            description="🎉 New torrent added: $additional_data"
            color=34979  # Correct decimal color code for blue
            fields="[ { \"name\": \"Torrent Name\", \"value\": \"$additional_data\" }, { \"name\": \"Status\", \"value\": \"Downloading\" }, { \"name\": \"Time ($TZ)\", \"value\": \"$(date +"%Y-%m-%d %H:%M:%S")\" } ]"
            ;;
        "metadata_stuck")
            if [[ "${METADATA_STUCK_NOTIFICATION}" == "off" ]]; then
                echo "Metadata stuck notifications are disabled."
                return
            fi
            title="QbitMonitor: Torrent Metadata Stuck"
            description="⚠️ Torrent is stuck downloading metadata: $additional_data"
            color=16776960  # Yellow color for metadata stuck
            fields="[ { \"name\": \"Torrent Name\", \"value\": \"$additional_data\" }, { \"name\": \"Status\", \"value\": \"Stuck\" }, { \"name\": \"Time ($TZ)\", \"value\": \"$(date +"%Y-%m-%d %H:%M:%S")\" } ]"
            ;;
        "port_updated")
            if [[ "${PORT_UPDATED_NOTIFICATION}" == "off" ]]; then
                echo "Port updated notifications are disabled."
                return
            fi
            title="QbitMonitor: Listen Port Updated"
            description="🚢 Port updated to: $additional_data"
            color=800080
            fields="[ { \"name\": \"Listen port\", \"value\": \"$additional_data\" }, { \"name\": \"Status\", \"value\": \"Updated\" }, { \"name\": \"Time ($TZ)\", \"value\": \"$(date +"%Y-%m-%d %H:%M:%S")\" } ]"
            ;;
        "completed")
            if [[ "${DOWNLOAD_COMPLETE_NOTIFICATION}" == "off" ]]; then
                echo "Download complete notifications are disabled."
                return
            fi
            title="QbitMonitor: Torrent Completed"
            description="✅ Torrent is finished downloading: $additional_data"
            color=65280  # Green color for completion
            fields="[ { \"name\": \"Name\", \"value\": \"$additional_data\" }, { \"name\": \"Status\", \"value\": \"Complete\" }, { \"name\": \"Time ($TZ)\", \"value\": \"$(date +"%Y-%m-%d %H:%M:%S")\" } ]"
            ;;
        "qbittorrent_online")
            if [[ "${QBITTORRENT_STATUS_NOTIFICATION}" == "off" ]]; then
                echo "qBittorrent online notifications are disabled."
                return
            fi
            title="QbitMonitor: qBittorrent Online"
            description="🟢 qBittorrent is now online."
            color=3066993  # Green
            fields="[ { \"name\": \"Time ($TZ)\", \"value\": \"$(date +"%Y-%m-%d %H:%M:%S")\" } ]"
            ;;
        "qbittorrent_offline")
            if [[ "${QBITTORRENT_STATUS_NOTIFICATION}" == "off" ]]; then
                echo "qBittorrent offline notifications are disabled."
                return
            fi
            title="QbitMonitor: qBittorrent Offline"
            description="🔴 qBittorrent is currently offline."
            color=15158332  # Red
            fields="[ { \"name\": \"Time ($TZ)\", \"value\": \"$(date +"%Y-%m-%d %H:%M:%S")\" } ]"
            ;;
        *)
            echo "Unknown message type: $message_type"
            return
            ;;
    esac

    # Construct the embed JSON
    EMBED_MESSAGE=$(cat <<EOF
{
    "embeds": [{
        "title": "$title",
        "description": "$description",
        "color": $color,
        "fields": $fields,
        "footer": {
            "text": "https://github.com/jtmb/qbit-monitor"
        }
    }]
}
EOF
)

    # Print the JSON to check if it looks correct
    echo "Payload to be sent to Discord: $EMBED_MESSAGE"

    # Send the embed message via Discord webhook
    curl -X POST -H "Content-Type: application/json" -d "$EMBED_MESSAGE" "$DISCORD_WEBHOOK_URL"
}
