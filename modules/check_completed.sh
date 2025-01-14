#!/bin/bash

check_completed_torrents() {
    local torrents="$1"
    local notified_file="$2"

    # Print debug info for each torrent's state and progress
    echo "Checking completed torrents..."
    # echo "$torrents" | jq -r '.[] | "\(.name): State: \(.state), Progress: \(.progress)"'

    # Extract torrents that are fully downloaded (progress == 1) and in "uploading", "completed" or "stalledUP" state
    completed_torrents=$(echo "$torrents" | jq -r '.[] | select(.progress == 1 and (.state == "uploading" or .state == "completed" or .state == "stalledUP")) | .hash')

    # If there are completed torrents
    if [[ -n "$completed_torrents" ]]; then
        for hash in $completed_torrents; do
            # Get the name of the torrent based on the hash
            name=$(echo "$torrents" | jq -r ".[] | select(.hash == \"$hash\") | .name")

            # Check if notification has already been sent for this torrent
            if ! grep -q "$hash-completed" "$notified_file"; then
                echo "Sending completed notification for torrent: $name"
                send_discord_notification "completed" "$name"
                echo "$hash-completed" >> "$notified_file"
            fi
        done
    else
        echo "No completed torrents to notify."
    fi
}
