#!/bin/bash

# Function to send Discord notifications
send_discord_notification() {
    local message_type="$1"
    local additional_data="$2"
    local title description color fields
    TZ=$(date +%Z)

    # Define the title and description for each notification type
    case "$message_type" in
        "stalled")
            title="QbitMonitor: Torrent Stalled"
            description="⚠️ Torrent is stalled: $additional_data"
            color=16711680  # Red color for stalled
            fields="[ { \"name\": \"Torrent Name\", \"value\": \"$additional_data\" }, { \"name\": \"Status\", \"value\": \"Stalled\" }, { \"name\": \"Time ($TZ)\", \"value\": \"$(date +"%Y-%m-%d %H:%M:%S")\" }  ]"
            ;;
        "resumed")
            title="QbitMonitor: Torrent Resumed"
            description="➕ Torrent has resumed: $additional_data"
            color=65280  # Green color for resumed
            fields="[ { \"name\": \"Torrent Name\", \"value\": \"$additional_data\" }, { \"name\": \"Status\", \"value\": \"Resumed\" }, { \"name\": \"Time ($TZ)\", \"value\": \"$(date +"%Y-%m-%d %H:%M:%S")\" }  ]"
            ;;
        "new")
            title="QbitMonitor: New Torrent Added"
            description="🎉 New torrent added: $additional_data"
            color=34979  # Correct decimal color code for blue
            fields="[ { \"name\": \"Torrent Name\", \"value\": \"$additional_data\" }, { \"name\": \"Status\", \"value\": \"Downloading\" }, { \"name\": \"Time ($TZ)\", \"value\": \"$(date +"%Y-%m-%d %H:%M:%S")\" }  ]"
            ;;
        "metadata_stuck")
            title="QbitMonitor: Torrent Metadata Stuck"
            description="⚠️ Torrent is stuck downloading metadata: $additional_data"
            color=16776960  # Yellow color for metadata stuck
            fields="[ { \"name\": \"Torrent Name\", \"value\": \"$additional_data\" }, { \"name\": \"Status\", \"value\": \"Stuck\" }, { \"name\": \"Time ($TZ)\", \"value\": \"$(date +"%Y-%m-%d %H:%M:%S")\" }  ]"
            ;;
        "port_updated")
            title="QbitMonitor: Listen Port Updated"
            description="🚢  Port updated to: $additional_data"
            color=800080
            fields="[ { \"name\": \"Listen port\", \"value\": \"$additional_data\" }, { \"name\": \"Status\", \"value\": \"Updated\" }, { \"name\": \"Time ($TZ)\", \"value\": \"$(date +"%Y-%m-%d %H:%M:%S")\" } ]"
            ;;
        *)
            title="QbitMonitor: Torrent Completed"
            description="✅ Torrent is finished Downloading: $additional_data"
            color=65280  # Default color for unknown notifications
            fields="[ { \"name\": \"Name\", \"value\": \"$additional_data\" }, { \"name\": \"Status\", \"value\": \"Complete\" }, { \"name\": \"Time ($TZ)\", \"value\": \"$(date +"%Y-%m-%d %H:%M:%S")\" } ]"
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
