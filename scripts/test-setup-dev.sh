#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd -- "$SCRIPT_DIR/.." && pwd)

# shellcheck disable=SC1091
source "$REPO_ROOT/setup-dev.sh"

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

assert_eq() {
    local expected="$1"
    local actual="$2"
    local message="$3"

    if [[ "$actual" != "$expected" ]]; then
        printf 'FAIL: %s\nexpected:\n%s\nactual:\n%s\n' "$message" "$expected" "$actual" >&2
        exit 1
    fi
}

with_temp_dir() {
    local tmp_dir

    tmp_dir=$(mktemp -d)
    pushd "$tmp_dir" >/dev/null
    "$@"
    popd >/dev/null
    rm -rf "$tmp_dir"
}

test_collect_required_env_refs() {
    cat > service.yml <<'YAML'
services:
  app:
    image: example/app
    env_file:
      - path: ./.env-required
      - path: ./.env-optional
        required: false
  worker:
    image: example/worker
    env_file: [./.env-inline]
YAML

    local actual expected
    actual=$(collect_required_env_refs service.yml)
    expected=$'./.env-required\n./.env-inline'

    assert_eq "$expected" "$actual" "collect_required_env_refs should skip optional env files"
}

test_set_env_value_replaces_only_exact_key() {
    printf 'KEEP=1\nFOO=old\nFOO_SUFFIX=keep\n' > .env

    set_env_value FOO new .env

    local actual expected
    actual=$(<.env)
    expected=$'KEEP=1\nFOO_SUFFIX=keep\nFOO=new'

    assert_eq "$expected" "$actual" "set_env_value should replace exact keys and preserve similar names"
}

test_ci_placeholder_only_runs_in_ci() {
    : > .env
    unset TEST_CI_PLACEHOLDER TEST_NON_CI_PLACEHOLDER

    CI=true ensure_ci_placeholder TEST_CI_PLACEHOLDER ci-placeholder
    grep -qx 'TEST_CI_PLACEHOLDER=ci-placeholder' .env ||
        fail "ensure_ci_placeholder should write missing CI placeholders"

    CI=false ensure_ci_placeholder TEST_NON_CI_PLACEHOLDER should-not-write
    if grep -q '^TEST_NON_CI_PLACEHOLDER=' .env; then
        fail "ensure_ci_placeholder should not write placeholders outside CI"
    fi
}

test_homelab_host_ip_detection_failure() {
    : > .env
    unset HOMELAB_HOST_IP

    # shellcheck disable=SC2329
    detect_primary_ipv4() {
        return 1
    }

    if ensure_homelab_host_ip; then
        fail "ensure_homelab_host_ip should fail when detection fails"
    fi

    if grep -q '^HOMELAB_HOST_IP=' .env; then
        fail "ensure_homelab_host_ip should not write an empty host IP"
    fi
}

with_temp_dir test_collect_required_env_refs
with_temp_dir test_set_env_value_replaces_only_exact_key
with_temp_dir test_ci_placeholder_only_runs_in_ci
with_temp_dir test_homelab_host_ip_detection_failure

printf 'setup-dev.sh tests passed\n'
