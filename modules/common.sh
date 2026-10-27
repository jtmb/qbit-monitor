#!/bin/bash

# Function to check if a variable is set
check_var() {
    local var_name="$1"
    local var_value="${!var_name}"
    if [ -z "$var_value" ]; then
        echo "Error: MANDATORY VAR '$var_name' is not set." >&2
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

# Each Bash process owns private tmpfs session files. The port worker cannot
# remove the parent session. Credentials use pipes, never files or curl argv.
qbit_cookie_cleanup() {
    if [[ "${QBIT_COOKIE_OWNER:-}" == "$BASHPID" && -n "${QBIT_COOKIE_DIR:-}" ]]; then
        rm -f -- "$QBIT_COOKIE_DIR/cookies" "$QBIT_COOKIE_DIR/login-body"
        rmdir -- "$QBIT_COOKIE_DIR" 2>/dev/null || true
    fi
    unset QBIT_COOKIE_DIR QBIT_COOKIE_JAR QBIT_COOKIE_OWNER
}

login_to_qbittorrent() {
    local status body
    qbit_cookie_cleanup
    if [[ "$(stat -f -c %T /dev/shm 2>/dev/null)" != tmpfs ]]; then
        echo "Error: qBittorrent session storage requires tmpfs /dev/shm" >&2
        return 1
    fi
    QBIT_COOKIE_DIR=$(mktemp -d /dev/shm/qbit-monitor-auth.XXXXXXXX) || return 1
    QBIT_COOKIE_OWNER=$BASHPID
    QBIT_COOKIE_JAR="$QBIT_COOKIE_DIR/cookies"
    if ! status=$(curl -sS --connect-timeout 10 --max-time 30 -X POST \
        "$QBITTORRENT_HOST/api/v2/auth/login" \
        --data-urlencode username@/dev/fd/3 \
        --data-urlencode password@/dev/fd/4 \
        --cookie-jar "$QBIT_COOKIE_JAR" --output "$QBIT_COOKIE_DIR/login-body" \
        --write-out '%{http_code}' \
        3< <(printf '%s' "$QBITTORRENT_USERNAME") \
        4< <(printf '%s' "$QBITTORRENT_PASSWORD")); then
        qbit_cookie_cleanup
        return 1
    fi
    body=$(cat "$QBIT_COOKIE_DIR/login-body")
    rm -f -- "$QBIT_COOKIE_DIR/login-body"
    # 5.1 returns 200/Ok.; 5.3 returns 204/empty. A legacy 200/Fails.
    # is a failure. Curl transports SID, QBT_SID_<port>, or custom names.
    if ! { [[ "$status" == 200 && "$body" == 'Ok.' ]] ||
           [[ "$status" == 204 && -z "$body" ]]; }; then
        qbit_cookie_cleanup
        return 1
    fi
    if ! awk -F '\t' 'NF >= 7 && $6 != "" && $7 != "" { found=1 } END { exit !found }' "$QBIT_COOKIE_JAR"; then
        qbit_cookie_cleanup
        return 1
    fi
}

qbit_api() {
    [[ -s "${QBIT_COOKIE_JAR:-}" ]] || return 1
    curl --connect-timeout 10 --max-time 30 --cookie "$QBIT_COOKIE_JAR" "$@"
}

# A subshell owns and cleans its fresh session; no shared cookie filename.
get_torrents() (
    trap qbit_cookie_cleanup EXIT
    login_to_qbittorrent || return 1
    local torrents
    torrents=$(qbit_api -fsS "$QBITTORRENT_HOST/api/v2/torrents/info") || return 1
    jq -e 'type == "array"' <<< "$torrents" >/dev/null || return 1
    printf '%s\n' "$torrents"
)
