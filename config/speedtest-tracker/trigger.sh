#!/usr/bin/env bash
set -uo pipefail

interval_seconds=${SPEEDTEST_TRIGGER_INTERVAL_SECONDS:-3600}
speedtest_host="speed.${DOMAIN:-traefik.me}"
traefik_url=${SPEEDTEST_TRIGGER_TRAEFIK_URL:-https://traefik}

log() {
    printf '%s %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

die() {
    log "$*"
    exit 1
}

require_command() {
    local cmd=$1

    command -v "$cmd" >/dev/null 2>&1 || die "missing required command: $cmd"
}

validate_config() {
    [[ $interval_seconds =~ ^[0-9]+$ ]] || die 'SPEEDTEST_TRIGGER_INTERVAL_SECONDS must be an integer'
    (( interval_seconds > 0 )) || die 'SPEEDTEST_TRIGGER_INTERVAL_SECONDS must be greater than zero'
}

request() {
    local path=$1
    shift
    local -a extra_args=("$@")
    local output=''
    local status=0

    output=$(wget -qO- \
        --no-check-certificate \
        --header="Host: ${speedtest_host}" \
        --header='Accept: application/json' \
        "${extra_args[@]}" \
        "${traefik_url}${path}" 2>&1)
    status=$?

    if (( status != 0 )); then
        log "request_failed path=${path} exit_status=${status}" >&2
        return "$status"
    fi

    printf '%s' "$output"
}

wait_for_health() {
    local attempts=0
    local response=''

    while (( attempts < 24 )); do
        if response=$(request /api/healthcheck) && [[ $response == *'Speedtest Tracker is running!'* ]]; then
            return 0
        fi

        ((attempts += 1))
        sleep 5
    done

    log 'speedtest-tracker did not become ready after wake'
    return 1
}

run_once() {
    local queued_run=''
    local active_result=0

    if [[ -z ${SPEEDTEST_API_TOKEN:-} ]]; then
        log 'SPEEDTEST_API_TOKEN is unset; skipping automated speedtest trigger'
        return 0
    fi

    if ! wait_for_health; then
        return 1
    fi

    has_active_speedtest
    active_result=$?

    if (( active_result == 0 )); then
        log 'speedtest already queued or running; skipping trigger'
        return 0
    fi

    if (( active_result != 1 )); then
        return 1
    fi

    if ! queued_run=$(request /api/v1/speedtests/run --header="Authorization: Bearer ${SPEEDTEST_API_TOKEN}" --post-data=''); then
        log 'failed to queue speedtest run'
        return 1
    fi

    if [[ $queued_run == *'"data"'* || $queued_run == *'"message"'* ]]; then
        log 'queued speedtest run'
        return 0
    fi

    log 'malformed_response endpoint=/api/v1/speedtests/run'
    return 1
}

has_active_speedtest() {
    local response=''
    local status=''

    for status in waiting started running checking benchmarking; do
        if ! response=$(request "/api/v1/results?filter%5Bstatus%5D=${status}" --header="Authorization: Bearer ${SPEEDTEST_API_TOKEN}"); then
            log 'failed to query in-progress speedtests'
            return 2
        fi

        if [[ $response != *'"data"'* ]]; then
            log "malformed_response endpoint=/api/v1/results status_filter=${status}"
            return 2
        fi

        if [[ ! $response =~ "data"[[:space:]]*:[[:space:]]*\[\] ]]; then
            return 0
        fi
    done

    return 1
}

main() {
    require_command date
    require_command sleep
    require_command wget
    validate_config

    while true; do
        sleep "$interval_seconds"
        run_once || true
    done
}

main "$@"
