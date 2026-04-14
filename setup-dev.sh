#!/usr/bin/env bash
set -euo pipefail

# Setup script for homelab development environment
# Copies .env.example when needed, generates dev-safe app keys, and reports missing required values

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

collect_required_env_refs() {
    local file="$1"
    local in_env_block=0
    local env_indent=0
    local current_path=""
    local current_required=1
    local line trimmed_line indent

    while IFS= read -r line || [[ -n "$line" ]]; do
        trimmed_line=${line#"${line%%[![:space:]]*}"}
        indent=$(( ${#line} - ${#trimmed_line} ))

        if (( in_env_block )) && [[ -n "$trimmed_line" ]] && (( indent <= env_indent )); then
            if [[ -n "$current_path" && $current_required -eq 1 ]]; then
                printf '%s\n' "$current_path"
            fi
            in_env_block=0
            current_path=""
            current_required=1
        fi

        if [[ $trimmed_line =~ ^env_file:[[:space:]]*\[(.*)\][[:space:]]*$ ]]; then
            while IFS= read -r inline_ref; do
                [[ -n "$inline_ref" ]] && printf '%s\n' "$inline_ref"
            done < <(grep -oE '\.?/\.env-[A-Za-z0-9_-]+' <<< "$trimmed_line" || true)
            continue
        fi

        if [[ $trimmed_line =~ ^env_file:[[:space:]]*$ ]]; then
            in_env_block=1
            env_indent=$indent
            current_path=""
            current_required=1
            continue
        fi

        if (( in_env_block )); then
            if [[ $trimmed_line =~ ^-[[:space:]]+path:[[:space:]]*(\.?/\.env-[A-Za-z0-9_-]+)[[:space:]]*$ ]]; then
                if [[ -n "$current_path" && $current_required -eq 1 ]]; then
                    printf '%s\n' "$current_path"
                fi
                current_path="${BASH_REMATCH[1]}"
                current_required=1
                continue
            fi

            if [[ $trimmed_line =~ ^required:[[:space:]]*false[[:space:]]*$ ]]; then
                current_required=0
            fi
        fi
    done < "$file"

    if (( in_env_block )) && [[ -n "$current_path" && $current_required -eq 1 ]]; then
        printf '%s\n' "$current_path"
    fi
}

has_config_value() {
    local var_name="$1"

    if [[ -n "${!var_name-}" ]]; then
        return 0
    fi

    [[ -f ".env" ]] && grep -Eq "^${var_name}=.+" ".env"
}

generate_base64_key() {
    openssl rand -base64 32 | tr -d '\n'
}

set_env_value() {
    local var_name="$1"
    local var_value="$2"
    local env_file="$3"
    local tmp_file

    tmp_file=$(mktemp)

    if [[ -f "$env_file" ]]; then
        grep -Ev "^${var_name}=" "$env_file" > "$tmp_file" || true
    fi

    printf '%s=%s\n' "$var_name" "$var_value" >> "$tmp_file"
    mv "$tmp_file" "$env_file"
}

ensure_generated_dev_key() {
    local var_name="$1"

    if has_config_value "$var_name"; then
        return 0
    fi

    if ! command -v openssl >/dev/null 2>&1; then
        log_warn "openssl is not available, so $var_name was not generated"
        return 1
    fi

    if [[ ! -f ".env" ]]; then
        log_warn ".env is missing, so $var_name was not generated"
        return 1
    fi

    set_env_value "$var_name" "$(generate_base64_key)" ".env"
    log_info "Generated development key: $var_name"
}

show_generation_hints() {
    log_info "Generator hints:"
    if command -v mkpasswd >/dev/null 2>&1; then
        log_info "  mkpasswd -l 32 -s 1      # passwords"
    fi
    log_info "  openssl rand -base64 32   # app keys and secrets"
}

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Prepare the homelab development environment.

Options:
    --help, -h    Show this help message

This script:
- Optionally copies .env.example to .env if missing
- Generates random app keys in .env when safe for local development
- Verifies required env_file references from included compose files
- Reports required secrets that must be set manually

Run this script before starting the homelab and pods stacks with docker compose.
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown argument: $1"
            show_usage
            exit 1
            ;;
    esac
done

log_info "Setting up the homelab development environment..."
log_info "setup-dev.sh leaves password-style credentials alone and only generates app keys"

ENV_FILES_DIR="services"

# Verify that all env_file references used by the root compose include set exist.
missing_env_files=()
while IFS= read -r included_file; do
    while IFS= read -r env_ref; do
        env_name=${env_ref#./}
        env_path="$ENV_FILES_DIR/$env_name"
        if [[ ! -f "$env_path" ]]; then
            missing_env_files+=("$env_path")
        fi
    done < <(collect_required_env_refs "$included_file")
done < <(sed -n 's/^  - \(services\/[^ ]*\.yml\).*/\1/p' docker-compose.yml)

if (( ${#missing_env_files[@]} > 0 )); then
    log_warn "Some env_file references from docker-compose.yml are still missing:"
    printf ' - %s\n' "${missing_env_files[@]}"
fi

# Optional: Create .env from .env.example if missing
if [[ ! -f ".env" && -f ".env.example" ]]; then
    log_warn "Copying .env.example to .env"
    cp .env.example .env
elif [[ ! -f ".env" ]]; then
    log_info "No .env file found. You can create one for custom environment variables."
fi

generated_key_failures=0
for generated_key in PAPERLESS_DBPASS IMMICH_DB_PASSWORD LISTMONK_db__password PAPERLESS_SECRET_KEY NEXTAUTH_SECRET MEILI_MASTER_KEY SPEEDTEST_APP_KEY; do
    if ! ensure_generated_dev_key "$generated_key"; then
        generated_key_failures=1
    fi
done

required_vars=(
    ACME_EMAIL
    CF_DNS_API_TOKEN
    IMMICH_DB_PASSWORD
    LISTMONK_db__password
    PAPERLESS_DBPASS
    PAPERLESS_ADMIN_PASSWORD
    PAPERLESS_SECRET_KEY
    NEXTAUTH_SECRET
    MEILI_MASTER_KEY
    RUSTFS_ACCESS_KEY
    RUSTFS_SECRET_KEY
    OPENVPN_USER
    OPENVPN_PASSWORD
    SPEEDTEST_APP_KEY
)

missing_required_vars=()
for required_var in "${required_vars[@]}"; do
    if ! has_config_value "$required_var"; then
        missing_required_vars+=("$required_var")
    fi
done

if (( ${#missing_required_vars[@]} > 0 )); then
    log_warn "Missing required variables for docker compose --profile all:"
    printf ' - %s\n' "${missing_required_vars[@]}"
    log_warn "Set them in .env, direnv, or Dockhand before starting the stack"
    show_generation_hints
elif (( generated_key_failures > 0 )); then
    log_warn "Some development keys were not generated automatically"
    show_generation_hints
fi

log_info "Setup complete!"
log_info ""
log_info "Next steps:"
log_info "1. Start the main homelab stack (infra + apps):"
log_info "   docker compose --profile all up -d"
log_info "2. Start the separate Dockhand bootstrap stack:"
log_info "   docker compose -f docker-compose.pods.yml up -d"
log_info "3. Start only infrastructure:"
log_info "   docker compose --profile infra up -d"
log_info "4. Start only applications (requires infra running):"
log_info "   docker compose --profile apps up -d"
log_info "5. Start Home Assistant (separate stack):"
log_info "   cd home-assistant && docker compose --env-file ../.env --profile service up -d"
log_info "6. Set required secrets in .env, direnv, or Dockhand before docker compose up"
log_info ""
log_info "View main stack status: docker compose ps"
log_info "View pods stack status: docker compose -f docker-compose.pods.yml ps"
log_info "Stop main stack: docker compose down"
log_info "Stop pods stack: docker compose -f docker-compose.pods.yml down"
