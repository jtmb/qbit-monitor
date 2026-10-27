#!/bin/bash

# One authenticated, verified update; reusable by the existing background loop.
update_qbittorrent_port() {
    local tcpport response current_port status payload verified_port
    tcpport=$(cat "${PORT_FORWARD_FILE}") || return 1
    if [[ ! "$tcpport" =~ ^[0-9]{1,5}$ ]] || (( 10#$tcpport < 1 || 10#$tcpport > 65535 )); then
        echo "Error: Invalid forwarded port" >&2
        return 1
    fi
    tcpport=$((10#$tcpport))
    echo "Glueten VPN port is set to $tcpport"
    if ! login_to_qbittorrent; then
        echo "Login failed" >&2
        return 1
    fi
    echo "Login successful"

    response=$(qbit_api -fsS "$QBITTORRENT_HOST/api/v2/app/preferences") || return 1
    current_port=$(jq -er '.listen_port | select(type == "number" and . == floor and . >= 1 and . <= 65535)' <<< "$response") || {
        echo "Error: Valid listen_port missing from API response" >&2
        return 1
    }
    echo "Current Qbittorrent listen_port is $current_port"
    if [[ "$tcpport" != "$current_port" ]]; then
        echo "Port has changed - Updating Qbittorrent listen_port to $tcpport 🚨"
        payload=$(jq -nc --argjson port "$tcpport" '{listen_port: $port}') || return 1
        status=$(qbit_api -sS -o /dev/null -w '%{http_code}' \
            "$QBITTORRENT_HOST/api/v2/app/setPreferences" --data-urlencode "json=$payload") || return 1
        [[ "$status" == 200 || "$status" == 204 ]] || return 1
        response=$(qbit_api -fsS "$QBITTORRENT_HOST/api/v2/app/preferences") || return 1
        verified_port=$(jq -er '.listen_port' <<< "$response") || return 1
        if [[ "$verified_port" != "$tcpport" ]]; then
            echo "Error: qBittorrent listen_port update was not confirmed" >&2
            return 1
        fi
        echo "Qbittorrent listen_port updated to $tcpport ✔️"
        send_discord_notification "port_updated" "$tcpport"
    else
        echo "Port is unchanged. No update needed."
    fi
}

monitor_qbittorrent_port() {
    CHECK_INTERVAL=${CHECK_INTERVAL:-10}
    trap qbit_cookie_cleanup EXIT
    while true; do
        if update_qbittorrent_port; then
            echo "Waiting for $CHECK_INTERVAL_FORWARDED_PORT before next port check iteration..."
            sleep "$CHECK_INTERVAL_FORWARDED_PORT"
        else
            # Failed logins/requests must not create a tight retry/ban loop.
            sleep "$CHECK_INTERVAL"
        fi
        echo "------------------------------------------------------------------------------------"
        echo ""
    done
}

export -f monitor_qbittorrent_port
