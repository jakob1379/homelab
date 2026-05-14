#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

write_stubs() {
    mkdir -p bin

    cat > bin/date <<'SH'
#!/usr/bin/env bash
printf '2026-05-14T00:00:00Z\n'
SH

    cat > bin/sleep <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$SLEEP_LOG"
SH

    cat > bin/wget <<'SH'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$WGET_LOG"

if [[ ! -s "$WGET_RESPONSES" ]]; then
    printf 'wget stub has no queued response\n' >&2
    exit 99
fi

IFS='|' read -r status body < "$WGET_RESPONSES"
tail -n +2 "$WGET_RESPONSES" > "${WGET_RESPONSES}.next"
mv "${WGET_RESPONSES}.next" "$WGET_RESPONSES"

printf '%s' "$body"
exit "$status"
SH

    chmod +x bin/date bin/sleep bin/wget
}

queue_response() {
    printf '%s|%s\n' "$1" "$2" >> "$WGET_RESPONSES"
}

queue_empty_result_responses() {
    local status

    for status in waiting started running checking benchmarking; do
        queue_response 0 '{"data":[]}'
    done
}

with_fixture() {
    local tmp_dir

    tmp_dir=$(mktemp -d)
    pushd "$tmp_dir" >/dev/null
    write_stubs
    export PATH="$PWD/bin:$PATH"
    export WGET_LOG="$PWD/wget.log"
    export SLEEP_LOG="$PWD/sleep.log"
    export WGET_RESPONSES="$PWD/wget-responses"
    : > "$WGET_LOG"
    : > "$SLEEP_LOG"
    : > "$WGET_RESPONSES"

    # shellcheck disable=SC1091
    source "$REPO_ROOT/config/speedtest-tracker/trigger.sh"

    "$@"

    popd >/dev/null
    rm -rf "$tmp_dir"
}

assert_status() {
    local expected="$1"
    shift
    local status

    set +e
    "$@"
    status=$?
    set -e

    [[ $status -eq $expected ]] || fail "$* returned $status, expected $expected"
}

test_token_missing_skips_requests() {
    unset SPEEDTEST_API_TOKEN

    assert_status 0 run_once

    [[ ! -s "$WGET_LOG" ]] || fail "run_once should not call wget without a token"
}

test_healthcheck_success() {
    queue_response 0 'Speedtest Tracker is running!'

    wait_for_health

    grep -q '/api/healthcheck' "$WGET_LOG" || fail "healthcheck should request /api/healthcheck"
}

test_healthcheck_failure_retries() {
    for _ in {1..24}; do
        queue_response 1 'down'
    done

    assert_status 1 wait_for_health

    [[ $(wc -l < "$SLEEP_LOG") -eq 24 ]] || fail "healthcheck failure should sleep between all retries"
}

test_active_result_detection() {
    export SPEEDTEST_API_TOKEN=test-token
    queue_response 0 '{"data":[{"id":1,"status":"running"}]}'

    has_active_speedtest
}

test_empty_result_detection() {
    export SPEEDTEST_API_TOKEN=test-token
    queue_empty_result_responses

    assert_status 1 has_active_speedtest
}

test_queue_success() {
    export SPEEDTEST_API_TOKEN=test-token
    queue_response 0 'Speedtest Tracker is running!'
    queue_empty_result_responses
    queue_response 0 '{"data":{"id":1}}'

    assert_status 0 run_once

    grep -q '/api/v1/speedtests/run' "$WGET_LOG" ||
        fail "run_once should call the queue endpoint when no run is active"
}

test_malformed_results_response() {
    export SPEEDTEST_API_TOKEN=test-token
    queue_response 0 'not-json'

    assert_status 2 has_active_speedtest
}

test_malformed_queue_response() {
    export SPEEDTEST_API_TOKEN=test-token
    queue_response 0 'Speedtest Tracker is running!'
    queue_empty_result_responses
    queue_response 0 'not-json'

    assert_status 1 run_once
}

with_fixture test_token_missing_skips_requests
with_fixture test_healthcheck_success
with_fixture test_healthcheck_failure_retries
with_fixture test_active_result_detection
with_fixture test_empty_result_detection
with_fixture test_queue_success
with_fixture test_malformed_results_response
with_fixture test_malformed_queue_response

printf 'speedtest trigger tests passed\n'
