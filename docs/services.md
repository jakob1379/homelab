# Service Reference

This page lists the active services, their URLs, their profile membership, and their current sleep behavior. If you need the routing model first, read [Architecture](architecture.md).

---

## Try It Now

```bash title="Start a small but representative slice"
# 1. Start the foundation
$ docker compose --profile infra up -d
[+] Running ...
 ✔ Container homelab-traefik-1   Started
 ✔ Container homelab-sablier-1   Started

# 2. Start two sleeping apps
$ docker compose --profile apps up -d keep speedtest-tracker
[+] Running ...
 ✔ Container homelab-keep-1               Started
 ✔ Container homelab-speedtest-tracker-1  Started

# 3. Verify both routes
$ curl https://keep.localhost.me
<!doctype html>
...

$ curl https://speed.localhost.me
<!DOCTYPE html>
...
```

`keep` and `speedtest-tracker` both go through file-provider **Sablier** routes.

---

## Bootstrap Control Plane

| Service | Access | Compose file | Sleep | Notes |
|---|---|---|---|---|
| **Dockhand** | `http://localhost:3000` during bootstrap, `https://docker.${DOMAIN}` after the main stack is up | `services/compose-pods.yml` via `docker-compose.pods.yml` | No | separate stack on shared `traefik_public` |

---

## Foundation Services

| Service | Access | Profile(s) | Routing source | Sleep | Notes |
|---|---|---|---|---|---|
| **Traefik** | `https://traefik.${DOMAIN}` | `infra`, `dev`, `prod` | Docker labels | No | reverse proxy and dashboard |
| **Sablier** | internal only | `infra`, `dev`, `prod` | none | No | Docker provider for sleep-on-request |
| **whoami** | `https://whoami.${DOMAIN}` | `infra`, `dev`, `prod` | `config/traefik/dyn/whoami.yml` | Yes, `10m` | uses `sablier-default@file` |
| **RustFS** | `https://rustfs.${DOMAIN}`, `https://rustfs-api.${DOMAIN}` | `infra`, `dev`, `prod` | `config/traefik/dyn/rustfs.yml` | No | object storage and console |
| **AdGuard Home** | `https://dns.${DOMAIN}` and host DNS port `${ADGUARD_DNS_PORT}` | `infra`, `dev`, `prod` | Docker labels | No | publishes port `53` on the configured host port |
| **NetAlertX** | `https://netalertx.${DOMAIN}` | `infra`, `dev`, `prod` | `config/traefik/dyn/netalertx.yml` | No | host networking for LAN scanning |

---

## Utilities And Dashboards

| Service | Access | Profile(s) | Routing source | Sleep | Notes |
|---|---|---|---|---|---|
| **Homepage** | `https://home.${DOMAIN}` | `apps`, `dev`, `prod` | `config/traefik/dyn/home.yml` | Yes, `30m` | auto-discovers most entries from Docker labels |
| **AnythingLLM** | `https://llm.${DOMAIN}` | `apps`, `dev`, `prod` | `config/traefik/dyn/anythingllm.yml` | Yes, `30m` | keeps `SYS_ADMIN` and `host.docker.internal` mapping |
| **IT Tools** | `https://it.${DOMAIN}` | `apps`, `dev`, `prod` | `config/traefik/dyn/ittools.yml` | Yes, `30m` | developer utilities |
| **CloudBeaver** | `https://cbeaver.${DOMAIN}` | `apps`, `dev`, `prod` | `config/traefik/dyn/cbeaver.yml` | Yes, `30m` | DB UI |
| **BentoPDF** | `https://pdf.${DOMAIN}` | `apps`, `dev`, `prod` | `config/traefik/dyn/bentopdf.yml` | Yes, `30m` | PDF tools |
| **Omni Tools** | `https://omni.${DOMAIN}` | `apps`, `dev`, `prod` | `config/traefik/dyn/omni-tools.yml` | Yes, `30m` | general utilities |
| **VERT** | `https://vert.${DOMAIN}` | `apps`, `dev`, `prod` | `config/traefik/dyn/vert.yml` | Yes, `30m` | browser-side file conversion |
| **Speedtest Tracker** | `https://speed.${DOMAIN}` | `apps`, `dev`, `prod` | `config/traefik/dyn/speedtest-tracker.yml` | Yes, `15m` | stores SQLite data under `/config`; `speedtest-trigger` wakes it hourly through the API |
| **DumbAssets** | `https://assets.${DOMAIN}` | `apps`, `dev`, `prod` | `config/traefik/dyn/dumbassets.yml` | Yes, `30m` | tracks assets, warranties, receipts, manuals, and maintenance |

---

## App Stacks

### Karakeep stack

| Service | Access | Profile(s) | Sleep | Notes |
|---|---|---|---|---|
| **keep** | `https://keep.${DOMAIN}` | `apps`, `dev`, `prod` | Yes, `15m` | file-provider route in `config/traefik/dyn/keep.yml` |
| `chrome` | internal only | `apps`, `dev`, `prod` | No | browser worker |
| `meilisearch` | internal only | `apps`, `dev`, `prod` | No | search backend |

Required vars:

- `NEXTAUTH_SECRET`
- `MEILI_MASTER_KEY`

Optional vars:

- `KARAKEEP_OPENAI_API_KEY`
- `KARAKEEP_OAUTH_WELLKNOWN_URL`
- `KARAKEEP_OAUTH_CLIENT_ID`
- `KARAKEEP_OAUTH_CLIENT_SECRET`
- `KARAKEEP_OAUTH_PROVIDER_NAME`

### Listmonk stack

| Service | Access | Profile(s) | Sleep | Notes |
|---|---|---|---|---|
| **listmonk** | `https://listmonk.${DOMAIN}` | `apps`, `dev`, `prod` | No in current routing | route file is `config/traefik/dyn/listmonk.yml` |
| `listmonk-postgres` | internal only | `apps`, `dev`, `prod` | No | app-local PostgreSQL |
| `cftunnel` | internal only | `tunnel` | No | optional sidecar |

Required var: `LISTMONK_db__password`

### Immich stack

| Service | Access | Profile(s) | Sleep | Notes |
|---|---|---|---|---|
| **immich-server** | `https://photos.${DOMAIN}` | `apps`, `dev`, `prod` | No | Docker-label route in `services/compose-immich.yml` |
| `immich-microservices` | internal only | `apps`, `dev`, `prod` | No | background workers |
| `immich-machine-learning` | internal only | `apps`, `dev`, `prod` | No | ML service |
| `redis` | internal only | `apps`, `dev`, `prod` | No | queue/cache |
| `immich-postgres` | internal only | `apps`, `dev`, `prod` | No | app-local PostgreSQL |

Required var: `IMMICH_DB_PASSWORD`

### Paperless-ngx stack

| Service | Access | Profile(s) | Sleep | Notes |
|---|---|---|---|---|
| **paperless-web** | `https://paper.${DOMAIN}` | `apps`, `dev`, `prod` | Yes, `15m` | route file is `config/traefik/dyn/paperless.yml` |
| `paperless-consumer` | internal only | `apps`, `dev`, `prod` | No | background consumer |
| `paperless-postgres` | internal only | `apps`, `dev`, `prod` | No | app-local PostgreSQL |
| `paperless-redis` | internal only | `apps`, `dev`, `prod` | No | Redis |
| `paperless-gotenberg` | internal only | `apps`, `dev`, `prod` | No | document conversion |
| `paperless-tika` | internal only | `apps`, `dev`, `prod` | No | document parsing |

Required vars:

- `PAPERLESS_DBPASS`
- `PAPERLESS_ADMIN_PASSWORD`
- `PAPERLESS_SECRET_KEY`

### Media stack

| Service | Access | Profile(s) | Routing source | Sleep | Notes |
|---|---|---|---|---|---|
| **Jellyfin** | `https://jellyfin.${DOMAIN}` | `apps`, `dev`, `prod` | Docker labels on `jellyfin` | No | media server |
| **Seerr** | `https://requests.${DOMAIN}` | `apps`, `dev`, `prod` | `config/traefik/dyn/seerr.yml` | Yes, `30m` | request UI |
| **Immich Power Tools** | `https://immich-tools.${DOMAIN}` | `apps`, `dev`, `prod` | `config/traefik/dyn/immich-power-tools.yml` | Yes, `30m` | separate helper app, not core Immich routing |
| **torrent** | `https://torrent.${DOMAIN}` | `apps`, `dev`, `prod` | Docker labels on `gluetun` | No | qBittorrent service name is `torrent`; shares `gluetun` network namespace |
| **Sonarr** | `https://sonarr.${DOMAIN}` | `apps`, `dev`, `prod` | Docker labels on `gluetun` | No | shares `gluetun` network namespace |
| **Radarr** | `https://radarr.${DOMAIN}` | `apps`, `dev`, `prod` | Docker labels on `gluetun` | No | shares `gluetun` network namespace |
| **FlareSolverr** | internal only, `http://flaresolverr:8191` from `media` | `apps`, `dev`, `prod` | None | No | shares `gluetun` network namespace |
| **Byparr** | internal only, `http://byparr:8192` from `media` | `apps`, `dev`, `prod` | None | No | FlareSolverr-compatible helper; shares `gluetun` network namespace |
| **Prowlarr** | `https://prowlarr.${DOMAIN}` | no explicit profile | Docker labels | No | starts by default in the main stack because it has no profile |
| **Bazarr** | `https://bazarr.${DOMAIN}` | `apps`, `dev`, `prod` | Docker labels on `bazarr` | No | subtitle management for the shared media library |

Current caveat:

- `gluetun` carries external Docker-label routes only for `torrent`, `sonarr`, and `radarr`
- `gluetun` also carries `torrent`, `sonarr`, `radarr`, `flaresolverr`, and `byparr` aliases on `media` to preserve internal service-name reachability
- configure Prowlarr's FlareSolverr indexer proxy host as `http://byparr:8192`, not `/v1`; Prowlarr appends `/v1`
- active compose requires `OPENVPN_USER` and `OPENVPN_PASSWORD` for Gluetun; `setup-dev.sh` writes local dummy values so config rendering works
- replace the dummy OpenVPN values before running VPN-backed downloads for real
- `VPN_SERVER_COUNTRIES` is optional and defaults to `Netherlands`

### Home Assistant

| Service | Access | Profile(s) | Routing source | Sleep | Notes |
|---|---|---|---|---|---|
| **ha** | `https://ha.${DOMAIN}` | `apps`, `service`, `dev`, `prod` | `config/traefik/dyn/ha.yml` | No | host networking for LAN discovery; files live under `home-assistant/` |

Narrow start command:

```bash title="Start only Home Assistant"
$ docker compose --profile service up -d ha
[+] Running 1/1
 ✔ Container homelab-ha-1  Started
```

---

## Required Variables

These are the compose-required variables that matter for the active stack.

| Variable | Used by |
|---|---|
| `RUSTFS_ACCESS_KEY` | **RustFS** |
| `RUSTFS_SECRET_KEY` | **RustFS** |
| `IMMICH_DB_PASSWORD` | **Immich**, **Immich Power Tools** |
| `LISTMONK_db__password` | **Listmonk** |
| `PAPERLESS_DBPASS` | **Paperless-ngx** |
| `PAPERLESS_ADMIN_PASSWORD` | **Paperless-ngx** |
| `PAPERLESS_SECRET_KEY` | **Paperless-ngx** |
| `NEXTAUTH_SECRET` | **Karakeep** |
| `MEILI_MASTER_KEY` | **Karakeep**, **Meilisearch** |
| `SPEEDTEST_APP_KEY` | **Speedtest Tracker** |
| `OPENVPN_USER` | **Gluetun** ProtonVPN OpenVPN username |
| `OPENVPN_PASSWORD` | **Gluetun** ProtonVPN OpenVPN password |
| `DUMBASSETS_PIN` | **DumbAssets** |
| `DUMBASSETS_SESSION_SECRET` | **DumbAssets** |

Optional vars:

- `SPEEDTEST_API_TOKEN` is used by the **Speedtest Trigger** sidecar; create it in Speedtest Tracker with `Read Results` and `Run Speedtest` abilities. When unset, the sidecar logs `skipped_no_token` and skips the trigger.

Bootstrap behavior:

- `.env.example` already provides local RustFS defaults.
- `setup-dev.sh` auto-generates `IMMICH_DB_PASSWORD`, `LISTMONK_db__password`, `PAPERLESS_DBPASS`, `PAPERLESS_SECRET_KEY`, `NEXTAUTH_SECRET`, `MEILI_MASTER_KEY`, `SPEEDTEST_APP_KEY`, and `DUMBASSETS_SESSION_SECRET` when they are missing.
- `setup-dev.sh` writes dummy `OPENVPN_USER`, `OPENVPN_PASSWORD`, and `DUMBASSETS_PIN` values for local config rendering. Real Gluetun use still needs real VPN credentials.
- `GLUETUN_HEALTHCHECK_DISABLED=true` is the local default so `docker compose --profile dev up --wait` can start the media UI routes with dummy VPN credentials. Set it to `false` when real VPN credentials should gate the stack.
- `setup-dev.sh` creates mkcert-backed local TLS files for `https://*.localhost.me` and writes Traefik's generated certificate dynamic config.
- In CI only, `setup-dev.sh` also writes a dummy `PAPERLESS_ADMIN_PASSWORD` value so local config rendering works without real secrets.
- For local full-stack runs, set `PAPERLESS_ADMIN_PASSWORD` yourself unless you already provide it through the environment.
- For production ACME certificates, use `docker compose --profile prod up -d` and set `DOMAIN`, `ACME_EMAIL`, and `CF_DNS_API_TOKEN`.

---

## Parked Definitions

These service files exist but are not active because the root include list does not reference them:

- `services/compose-hermes.yml`
- `services/compose-teable.yml`
- `services/compose-teable-migrate.yml`
