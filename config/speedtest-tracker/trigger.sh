#!/usr/bin/env bash
if [ -z "${BASH_VERSION:-}" ]; then
    printf '%s %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || printf unknown-time)" \
        'speedtest-trigger requires bash; run it with: bash /opt/speedtest-trigger/trigger.sh'
    return 2 2>/dev/null
    # shellcheck disable=SC2317
    exit 2
fi

set -uo pipefail

interval_seconds=${SPEEDTEST_TRIGGER_INTERVAL_SECONDS:-3600}
speedtest_host="speed.${DOMAIN:-localhost.me}"
traefik_url=${SPEEDTEST_TRIGGER_TRAEFIK_URL:-https://traefik}
response_body=''
response_status=''
response_error=''

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

request_capture() {
    local path=$1
    shift
    local -a extra_args=("$@")
    local body_file="/tmp/speedtest-trigger-body.$$"
    local headers_file="/tmp/speedtest-trigger-headers.$$"
    local exit_code=0

    response_body=''
    response_status=''
    response_error=''
    rm -f "$body_file" "$headers_file"

    wget -qS -O "$body_file" \
        --no-check-certificate \
        --header="Host: ${speedtest_host}" \
        --header='Accept: application/json' \
        "${extra_args[@]}" \
        "${traefik_url}${path}" 2>"$headers_file"
    exit_code=$?

    [[ -f $body_file ]] && response_body=$(<"$body_file")
    [[ -f $headers_file ]] && response_error=$(<"$headers_file")
    response_status=$(sed -n 's/^[[:space:]]*HTTP\/[0-9.]*[[:space:]]\+\([0-9][0-9][0-9]\).*/\1/p' "$headers_file" 2>/dev/null | tail -n 1)
    rm -f "$body_file" "$headers_file"

    return "$exit_code"
}

response_excerpt() {
    local excerpt=$response_body

    if [[ -z $excerpt ]]; then
        excerpt=$response_error
    fi

    excerpt=${excerpt//$'\r'/ }
    excerpt=${excerpt//$'\n'/ }
    excerpt=${excerpt//$'\t'/ }

    if [[ -n ${SPEEDTEST_API_TOKEN:-} ]]; then
        excerpt=${excerpt//${SPEEDTEST_API_TOKEN}/<redacted>}
    fi

    printf '%.240s' "$excerpt"
}

log_request_failure() {
    local action=$1
    local path=$2
    local status=${response_status:-unknown}
    local excerpt

    excerpt=$(response_excerpt)

    case "$status" in
        401 | 403)
            log "${action} failed: auth rejected for ${path} (http_status=${status}); check SPEEDTEST_API_TOKEN has Read Results and Run Speedtest abilities"
            ;;
        unknown)
            log "${action} failed: no HTTP response from ${traefik_url}${path}; check Traefik/Sablier routing from speedtest-trigger"
            ;;
        *)
            log "${action} failed: unexpected response from ${path} (http_status=${status})"
            ;;
    esac

    if [[ -n $excerpt ]]; then
        log "${action} response excerpt: ${excerpt}"
    fi
}

wait_for_health() {
    local attempts=0
    local response=''

    while (( attempts < 24 )); do
        log "healthcheck attempt $((attempts + 1))/24 for ${speedtest_host}"
        if response=$(request /api/healthcheck 2>/dev/null) && [[ $response == *'Speedtest Tracker is running!'* ]]; then
            log 'speedtest-tracker is ready'
            return 0
        fi

        ((attempts += 1))
        sleep 5
    done

    log 'speedtest-tracker did not become ready after wake (outcome=failed_healthcheck)'
    return 1
}

run_once() {
    local queued_run=''
    local active_result=0
    local token_state=absent

    if [[ -n ${SPEEDTEST_API_TOKEN:-} ]]; then
        token_state=present
    fi

    log "scheduled speedtest trigger started (host=${speedtest_host} route_base=${traefik_url} interval_seconds=${interval_seconds} token=${token_state})"

    if [[ -z ${SPEEDTEST_API_TOKEN:-} ]]; then
        log 'SPEEDTEST_API_TOKEN is unset; skipping automated speedtest trigger (outcome=skipped_no_token)'
        return 0
    fi

    if ! wait_for_health; then
        log 'scheduled speedtest trigger finished (outcome=failed_healthcheck)'
        return 1
    fi

    has_active_speedtest
    active_result=$?

    if (( active_result == 0 )); then
        log 'speedtest already queued or running; skipping trigger (outcome=skipped_active_speedtest)'
        return 0
    fi

    if (( active_result != 1 )); then
        log 'scheduled speedtest trigger finished (outcome=failed_active_query)'
        return 1
    fi

    log 'queueing speedtest run via /api/v1/speedtests/run'
    if ! request_capture /api/v1/speedtests/run --header="Authorization: Bearer ${SPEEDTEST_API_TOKEN}" --post-data=''; then
        log_request_failure 'queue speedtest run' /api/v1/speedtests/run
        log 'scheduled speedtest trigger finished (outcome=failed_queue)'
        return 1
    fi

    queued_run=$response_body

    if [[ $queued_run == *'"data"'* || $queued_run == *'"message"'* ]]; then
        log 'queued speedtest run (outcome=queued)'
        return 0
    fi

    log_request_failure 'queue speedtest run' /api/v1/speedtests/run
    log 'scheduled speedtest trigger finished (outcome=failed_unexpected_queue_response)'
    return 1
}

has_active_speedtest() {
    local status=''
    local path=''

    for status in waiting started running checking benchmarking; do
        path="/api/v1/results?filter%5Bstatus%5D=${status}"
        log "querying in-progress speedtests (status=${status})"
        if ! request_capture "$path" --header="Authorization: Bearer ${SPEEDTEST_API_TOKEN}"; then
            log_request_failure 'query in-progress speedtests' "$path"
            return 2
        fi

        if [[ $response_body != *'"data"'* ]]; then
            log_request_failure 'query in-progress speedtests' "$path"
            return 2
        fi

        if [[ ! $response_body =~ "data"[[:space:]]*:[[:space:]]*\[\] ]]; then
            log "found active speedtest result (status=${status})"
            return 0
        fi
    done

    log 'no queued or running speedtests found'
    return 1
}

main() {
    require_command date
    require_command sed
    require_command sleep
    require_command tail
    require_command wget
    validate_config

    log "speedtest-trigger started (interval_seconds=${interval_seconds} host=${speedtest_host} route_base=${traefik_url})"
    while true; do
        log "sleeping until next scheduled speedtest trigger (interval_seconds=${interval_seconds})"
        sleep "$interval_seconds"
        run_once || true
    done
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
