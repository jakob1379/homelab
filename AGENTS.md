# Project Overview
This repo is a Docker Compose homelab with Traefik for HTTPS routing, Sablier for
sleep-on-demand apps, and Portainer for bootstrap and Git-based deployment. It is built
to run locally with minimal setup and scale into a production-style self-hosted stack.
## Repository Structure
- `.github/` CI workflows, Dependabot config, and PR templates.
- `config/` Runtime config for Traefik and Homepage.
- `docs/` Source docs for the published documentation site.
- `home-assistant/` Separate Home Assistant compose project on `traefik_public`.
- `services/` Per-stack compose files, env files, and secret file paths.-
 `site/` Generated docs output; ignored by git.
- `traefik-config/` Local Traefik config/secrets area; secrets are ignored.
- `docker-compose.yml` Root compose entrypoint that includes `services/*.yml`.
- `docker-compose.override.yml` Local restart-policy overrides.
- `setup-dev.sh` Creates dummy env and secret files for local development.
- `README.md` Main overview, quick start, and operator docs.
- `backup_spec.md` Backup service design spec.
- `template-stack.yml` Portainer stack template.
- `flake.nix` Optional Nix dev shell.
- `zensical.toml` Docs site config.
- `AGENTS.md` Agent guide for this repo.
## Build & Development Commands
Install/bootstrap:
```bash
./setup-dev.sh
Run:
docker compose up -d
docker compose --profile infra up -d
docker compose --profile apps up -d
docker compose --profile pods up -d
cd home-assistant && docker compose --profile service up -d
Test/validate:
bash -n setup-dev.sh
bash setup-dev.sh
DOMAIN=test.traefik.me docker compose --profile all config
DOMAIN=test.traefik.me docker compose --profile all pull --dry-run
Lint:
pre-commit install
pre-commit run -a
uvx pre-commit run -a
Type-check:
# > TODO: No dedicated type-check command is defined in this repo.
Docs build:
uv run zensical build --clean
Debug:
docker compose ps
docker compose logs -f traefik
curl -k https://whoami.traefik.me
curl -sk https://localhost:9443/api/status | jq '.Version'
Deploy:
docker compose --profile pods up -d
Code Style & Conventions
- Keep compose config split by stack under services/.
- Put routing and middleware in config/traefik/dyn/*.yml.
- Put static Traefik platform config in config/traefik/traefik.yml.
- Use lowercase, hyphenated YAML filenames like paperless-ngx.yml.
- Use uppercase snake case for env vars.
- Shell scripts use Bash with set -euo pipefail.
- Linting is driven by .pre-commit-config.yaml:
  trailing-whitespace, end-of-file-fixer, check-yaml, check-json,
  check-added-large-files, detect-private-key, yamlfix, and shellcheck.
- home-assistant/configuration.yaml is excluded from check-yaml and yamlfix.
Commit message template:
type(scope): imperative summary
Architecture Notes
flowchart LR
    User --> Traefik
    Traefik --> Sablier
    Traefik --> App
    Sablier --> Docker
    Docker --> services
    Portainer --> Docker
    HomeAssistant --> traefik_public
docker-compose.yml includes per-stack files from services/. Traefik handles ingress,
TLS, and file-plus-Docker-provider routing. Sablier starts stopped app groups on demand.
Most apps join traefik_public plus a private stack network; stateful services keep
app-local databases and volumes. Portainer bootstrap uses the pods profile, then
deploys the full stack from Git.
Testing Strategy
- Unit tests:
  > TODO: No unit test suite is configured.
- Integration/config tests:
  Run bash -n setup-dev.sh,
  bash setup-dev.sh,
  DOMAIN=test.traefik.me docker compose --profile all config, and
  DOMAIN=test.traefik.me docker compose --profile all pull --dry-run.
- E2E/smoke:
  Run docker compose up -d and curl -k https://whoami.traefik.me.
- CI:
  .github/workflows/test-docker-compose.yml validates the setup script and Compose
  config; .github/workflows/docs.yml builds docs; .github/workflows/yamlfix.yml
  runs pre-commit auto-fixes.
Security & Compliance
- Secrets are file-based and untracked: .env, services/.env-*,
  services/secrets/*, and traefik-config/secrets/*.
- setup-dev.sh creates dummy local placeholders; do not commit real credentials.
- Traefik reads Cloudflare DNS credentials from services/secrets/cf_dns_api_token.
- Dependabot updates Docker dependencies monthly.
- Pre-commit includes secret-oriented guardrails such as detect-private-key.
- netalertx uses network_mode: host; review changes there carefully.
- License: MIT
Agent Guardrails
- Never edit or commit secret/state paths:
  .env, services/.env-*, services/secrets/*, traefik-config/secrets/*,
  home-assistant/config/, site/, .cache/, and log directories.
- Treat docker-compose.yml, services/networking.yml,
  config/traefik/traefik.yml, and home-assistant/docker-compose.yml as high-risk.
- Validate config changes with pre-commit run -a and
  DOMAIN=test.traefik.me docker compose --profile all config.
- Prefer stack-local changes over repo-wide refactors.
Extensibility Hooks
- Add new stacks as services/<name>.yml, then include them in docker-compose.yml.
- Add routes and Sablier middleware in config/traefik/dyn/*.yml.
- Use Compose profiles as feature flags:
  pods, infra, apps, all, experimental, tunnel.
- Main env hooks:
  DOMAIN, CF_API_EMAIL, ADGUARD_DNS_PORT,
  OPENVPN_USER, OPENVPN_PASSWORD, VPN_SERVER_COUNTRIES.
- services/immich.yml contains the experimental queue-driven wake pattern.
- template-stack.yml is the Portainer templating hook.
Further Reading
- README.md (README.md)
- docs/architecture.md (docs/architecture.md)
- docs/services.md (docs/services.md)
- docs/customization.md (docs/customization.md)
- docs/portainer.md (docs/portainer.md)
- docs/queue-driven-sleep.md (docs/queue-driven-sleep.md)
- docs/troubleshooting.md (docs/troubleshooting.md)
- backup_spec.md (backup_spec.md)
