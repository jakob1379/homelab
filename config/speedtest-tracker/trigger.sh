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

    wget -qO- \
        --no-check-certificate \
        --header="Host: ${speedtest_host}" \
        --header='Accept: application/json' \
        "${extra_args[@]}" \
        "${traefik_url}${path}"
}

wait_for_health() {
    local attempts=0
    local response=''

    while (( attempts < 24 )); do
        if response=$(request /api/healthcheck 2>/dev/null) && [[ $response == *'Speedtest Tracker is running!'* ]]; then
            return 0
        fi

        ((attempts += 1))
        sleep 5
    done

    log 'speedtest-tracker did not become ready after wake'
    return 1
}

run_once() {
    local started_runs=''
    local queued_run=''

    if [[ -z ${SPEEDTEST_API_TOKEN:-} ]]; then
        log 'SPEEDTEST_API_TOKEN is unset; skipping automated speedtest trigger'
        return 0
    fi

    if ! wait_for_health; then
        return 1
    fi

    if ! started_runs=$(request '/api/v1/results?filter[status]=Started' --header="Authorization: Bearer ${SPEEDTEST_API_TOKEN}" 2>/dev/null); then
        log 'failed to query in-progress speedtests'
        return 1
    fi

    if [[ $started_runs != *'"data"'* ]]; then
        log 'failed to query in-progress speedtests'
        return 1
    fi

    if [[ ! $started_runs =~ "data"[[:space:]]*:[[:space:]]*\[\] ]]; then
        log 'speedtest already queued or running; skipping trigger'
        return 0
    fi

    if ! queued_run=$(request /api/v1/speedtests/run --header="Authorization: Bearer ${SPEEDTEST_API_TOKEN}" --post-data='' 2>/dev/null); then
        log 'failed to queue speedtest run'
        return 1
    fi

    if printf '%s' "$queued_run" | grep -Eq '"data":[[:space:]]*[{[]'; then
        log 'queued speedtest run'
        return 0
    fi

    log 'failed to queue speedtest run'
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
