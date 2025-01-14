#!/bin/bash

check_new_torrents() {
    local torrents="$1"
    local notified_file="$2"

    # Print debug info for each torrent's state and added_on field
    echo "Checking new torrents..."
    # echo "$torrents" | jq -r '.[] | "\(.name): State: \(.state), Added On: \(.added_on)"'

    # Check for torrents that are in the "downloading" state but haven't been notified yet
    new_torrents=$(echo "$torrents" | jq -r '.[] | select(.state == "downloading" and .added_on != null) | .hash')

    # If there are new torrents to notify
    if [[ -n "$new_torrents" ]]; then
        for hash in $new_torrents; do
            name=$(echo "$torrents" | jq -r ".[] | select(.hash == \"$hash\") | .name")

            # Debugging the hash and name being processed
            echo "Processing torrent: $name (Hash: $hash)"

            # Check if the torrent has already been marked as "new" in the notified file
            if ! grep -q "$hash-new" "$notified_file"; then
                echo "Sending notification for new torrent: $name"
                send_discord_notification "new" "$name"
                echo "$hash-new" >> "$notified_file"
            else
                echo "Torrent already notified: $name"
            fi
        done
    else
        echo "No new torrents to notify."
    fi
}
