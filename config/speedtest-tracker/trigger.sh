#!/bin/sh
set -eu

interval_seconds=${SPEEDTEST_TRIGGER_INTERVAL_SECONDS:-3600}
speedtest_host="speed.${DOMAIN:-traefik.me}"
traefik_url=${SPEEDTEST_TRIGGER_TRAEFIK_URL:-https://traefik}

log() {
    printf '%s %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"
}

request() {
    path=$1
    shift

    wget -qO- \
        --no-check-certificate \
        --header="Host: ${speedtest_host}" \
        --header='Accept: application/json' \
        "$@" \
        "${traefik_url}${path}"
}

wait_for_health() {
    attempts=0

    while [ "$attempts" -lt 24 ]; do
        response=$(request /api/healthcheck 2>/dev/null || true)

        if printf '%s' "$response" | grep -q 'Speedtest Tracker is running!'; then
            return 0
        fi

        attempts=$((attempts + 1))
        sleep 5
    done

    log 'speedtest-tracker did not become ready after wake'
    return 1
}

run_once() {
    if [ -z "${SPEEDTEST_API_TOKEN:-}" ]; then
        log 'SPEEDTEST_API_TOKEN is unset; skipping automated speedtest trigger'
        return 0
    fi

    if ! wait_for_health; then
        return 1
    fi

    started_runs=$(request '/api/v1/results?filter[status]=Started' --header="Authorization: Bearer ${SPEEDTEST_API_TOKEN}" 2>/dev/null || true)

    if [ -z "$started_runs" ] || ! printf '%s' "$started_runs" | grep -q '"data"'; then
        log 'failed to query in-progress speedtests'
        return 1
    fi

    if ! printf '%s' "$started_runs" | grep -Eq '"data":[[:space:]]*\[\]'; then
        log 'speedtest already queued or running; skipping trigger'
        return 0
    fi

    queued_run=$(request /api/v1/speedtests/run --header="Authorization: Bearer ${SPEEDTEST_API_TOKEN}" --post-data='' 2>/dev/null || true)

    if printf '%s' "$queued_run" | grep -Eq '"data":[[:space:]]*[{[]'; then
        log 'queued speedtest run'
        return 0
    fi

    log 'failed to queue speedtest run'
    return 1
}

while true; do
    sleep "$interval_seconds"
    run_once || true
done
