#!/bin/bash

check_metadata_stuck_torrents() {
    local torrents="$1"
    local notified_file="$2"

    metadata_stuck_torrents=$(echo "$torrents" | jq -r '.[] | select(.state == "metaDL") | .hash')
    for hash in $metadata_stuck_torrents; do
        name=$(echo "$torrents" | jq -r ".[] | select(.hash == \"$hash\") | .name")
        
        # Check if the torrent is already marked as stuck and has been notified
        if ! grep -q "$hash-metaDL" "$notified_file"; then
            # Add the hash to the notified file if it has not been notified yet
            timestamp=$(date +%s)
            echo "$hash-metaDL:$timestamp" >> "$notified_file"
            send_discord_notification "metadata_stuck" "$name"
        fi
    done
}
