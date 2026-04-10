#!/usr/bin/env bash
set -euo pipefail

# Setup script for homelab development environment
# Creates dummy secret and environment files for local development

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

MANAGED_ENV_FILES=(
    ".env-listmonk"
    ".env-karakeep"
    ".env-immich"
    ".env-netalertx"
    ".env-rustfs"
    ".env-bentopdf"
    ".env-paperless"
    ".env-speedtest-tracker"
)

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

generate_base64_secret() {
    head -c 32 /dev/urandom | base64 | tr -d '\n'
}

show_usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Setup dummy files for homelab development environment.

Options:
    --help, -h    Show this help message

This script creates:
- services/.env-* dummy environment files (${#MANAGED_ENV_FILES[@]} files)
- Optional: .env from .env.example if missing
- Reminder: set VPN credentials in .env for media downloads

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

log_info "Setting up dummy files for homelab development..."

# Create environment files in services directory
ENV_FILES_DIR="services"
mkdir -p "$ENV_FILES_DIR"

# .env-listmonk
env_listmonk="$ENV_FILES_DIR/.env-listmonk"
if [[ ! -f "$env_listmonk" ]]; then
    log_warn "Creating dummy environment file: $env_listmonk"
    cat > "$env_listmonk" <<EOF
LISTMONK_db__user=listmonk
LISTMONK_db__password=dummy_password
LISTMONK_db__database=listmonk
LISTMONK_db__host=listmonk-postgres
LISTMONK_db__port=5432
LISTMONK_db__ssl_mode=disable
LISTMONK_app__address=0.0.0.0:9000
EOF
else
    log_info "Environment file $env_listmonk already exists"
fi

# .env-karakeep
env_karakeep="$ENV_FILES_DIR/.env-karakeep"
if [[ ! -f "$env_karakeep" ]]; then
    log_warn "Creating dummy environment file: $env_karakeep"
    cat > "$env_karakeep" <<EOF
MEILI_MASTER_KEY=dummy_master_key
NEXTAUTH_SECRET=dummy_secret_for_development
EOF
else
    log_info "Environment file $env_karakeep already exists"
fi

# .env-immich
env_immich="$ENV_FILES_DIR/.env-immich"
if [[ ! -f "$env_immich" ]]; then
    log_warn "Creating dummy environment file: $env_immich"
    cat > "$env_immich" <<EOF
# Immich photo management
DB_HOSTNAME=immich-postgres
DB_USERNAME=immich
DB_PASSWORD=immich
DB_DATABASE_NAME=immich
REDIS_HOSTNAME=redis
EOF
else
    log_info "Environment file $env_immich already exists"
fi

# .env-netalertx
env_netalertx="$ENV_FILES_DIR/.env-netalertx"
if [[ ! -f "$env_netalertx" ]]; then
    log_warn "Creating dummy environment file: $env_netalertx"
    echo "# NetAlertX network scanner configuration" > "$env_netalertx"
    echo "NETALERTX_SCAN_SUBNETS=192.168.1.0/24" >> "$env_netalertx"
else
    log_info "Environment file $env_netalertx already exists"
fi

# .env-rustfs
env_rustfs="$ENV_FILES_DIR/.env-rustfs"
if [[ ! -f "$env_rustfs" ]]; then
    log_warn "Creating dummy environment file: $env_rustfs"
    cat > "$env_rustfs" <<EOF
# RustFS object storage configuration
RUSTFS_ACCESS_KEY=dummy_access_key
RUSTFS_SECRET_KEY=dummy_secret_key
RUSTFS_CONSOLE_ENABLED=true
RUSTFS_CONSOLE_PORT=9001
EOF
else
    log_info "Environment file $env_rustfs already exists"
fi

# .env-bentopdf
env_bentopdf="$ENV_FILES_DIR/.env-bentopdf"
if [[ ! -f "$env_bentopdf" ]]; then
    log_warn "Creating dummy environment file: $env_bentopdf"
    echo "# BentoPDF configuration" > "$env_bentopdf"
else
    log_info "Environment file $env_bentopdf already exists"
fi

# .env-paperless
env_paperless="$ENV_FILES_DIR/.env-paperless"
if [[ ! -f "$env_paperless" ]]; then
    log_warn "Creating dummy environment file: $env_paperless"
    cat > "$env_paperless" <<EOF
# Paperless-ngx document management
PAPERLESS_SECRET_KEY=dummy_secret_key_for_development
PAPERLESS_OCR_LANGUAGE=eng
EOF
else
    log_info "Environment file $env_paperless already exists"
fi

# .env-speedtest-tracker
env_speedtest="$ENV_FILES_DIR/.env-speedtest-tracker"
if [[ ! -f "$env_speedtest" ]]; then
    log_warn "Creating dummy environment file: $env_speedtest"
    cat > "$env_speedtest" <<EOF
# Speedtest Tracker internet monitoring
APP_KEY=base64:$(generate_base64_secret)
SPEEDTEST_SCHEDULE=0 */6 * * *
DISPLAY_TIMEZONE=Europe/Copenhagen
PRUNE_RESULTS_OLDER_THAN=0
EOF
else
    log_info "Environment file $env_speedtest already exists"
fi

# Verify that all env_file references used by the root compose include set exist.
missing_env_files=()
while IFS= read -r included_file; do
    while IFS= read -r env_ref; do
        env_name=${env_ref#./}
        env_path="$ENV_FILES_DIR/$env_name"
        if [[ ! -f "$env_path" ]]; then
            missing_env_files+=("$env_path")
        fi
    done < <(grep -hoE '\.?/\.env-[A-Za-z0-9_-]+' "$included_file" || true)
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

if [[ -f ".env" ]] && (! grep -Eq '^OPENVPN_USER=' ".env" || ! grep -Eq '^OPENVPN_PASSWORD=' ".env"); then
    log_warn "Media download automation needs OPENVPN_USER and OPENVPN_PASSWORD in .env"
fi

log_info "Setup complete!"
log_info ""
log_info "Next steps:"
log_info "1. Start the main homelab stack (infra + apps):"
log_info "   docker compose --profile all up -d"
log_info "2. Start the separate Portainer + Dockhand stack:"
log_info "   docker compose -f docker-compose.pods.yml up -d"
log_info "3. Start only infrastructure:"
log_info "   docker compose --profile infra up -d"
log_info "4. Start only applications (requires infra running):"
log_info "   docker compose --profile apps up -d"
log_info "5. Start Home Assistant (separate stack):"
log_info "   cd home-assistant && docker compose --profile service up -d"
log_info "6. Enable media download automation (required for Gluetun):"
log_info "   set OPENVPN_USER and OPENVPN_PASSWORD in .env"
log_info ""
log_info "View main stack status: docker compose ps"
log_info "View pods stack status: docker compose -f docker-compose.pods.yml ps"
log_info "Stop main stack: docker compose down"
log_info "Stop pods stack: docker compose -f docker-compose.pods.yml down"
