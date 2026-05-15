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
$ curl http://keep.localhost
<!doctype html>
...

$ curl http://speed.localhost
<!DOCTYPE html>
...
```

`keep` and `speedtest-tracker` both go through file-provider **Sablier** routes.

---

## Bootstrap Control Plane

| Service | Access | Compose file | Sleep | Notes |
|---|---|---|---|---|
| **Dockhand** | `http://localhost:3000` during bootstrap, `${PUBLIC_SCHEME}://docker.${DOMAIN}` after the main stack is up | `services/bootstrap/pods.yml` via `docker-compose.pods.yml` | No | separate stack on shared `traefik_public` |

---

## Foundation Services

| Service | Access | Profile(s) | Routing source | Sleep | Notes |
|---|---|---|---|---|---|
| **Traefik** | `${PUBLIC_SCHEME}://traefik.${DOMAIN}` | `infra`, `all` | Docker labels | No | reverse proxy and dashboard |
| **Sablier** | internal only | `infra`, `all` | none | No | Docker provider for sleep-on-request |
| **whoami** | `${PUBLIC_SCHEME}://whoami.${DOMAIN}` | `infra`, `all` | `config/traefik/dyn/whoami.yml` | Yes, `10m` | uses `sablier-default@file` |
| **RustFS** | `${PUBLIC_SCHEME}://rustfs.${DOMAIN}`, `${PUBLIC_SCHEME}://rustfs-api.${DOMAIN}` | `infra`, `all` | `config/traefik/dyn/rustfs.yml` | No | object storage and console |
| **AdGuard Home** | `${PUBLIC_SCHEME}://dns.${DOMAIN}` and host DNS port `${ADGUARD_DNS_PORT}` | `infra`, `all` | Docker labels | No | publishes port `53` on the configured host port |
| **NetAlertX** | `${PUBLIC_SCHEME}://netalertx.${DOMAIN}` | `infra`, `all` | `config/traefik/dyn/netalertx.yml` | No | service itself runs in `network_mode: host` |

---

## Utilities And Dashboards

| Service | Access | Profile(s) | Routing source | Sleep | Notes |
|---|---|---|---|---|---|
| **Homepage** | `${PUBLIC_SCHEME}://home.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/home.yml` | Yes, `30m` | auto-discovers most entries from Docker labels |
| **AnythingLLM** | `${PUBLIC_SCHEME}://llm.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/anythingllm.yml` | Yes, `30m` | keeps `SYS_ADMIN` and `host.docker.internal` mapping |
| **IT Tools** | `${PUBLIC_SCHEME}://it.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/ittools.yml` | Yes, `30m` | developer utilities |
| **CloudBeaver** | `${PUBLIC_SCHEME}://cbeaver.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/cbeaver.yml` | Yes, `30m` | DB UI |
| **BentoPDF** | `${PUBLIC_SCHEME}://pdf.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/bentopdf.yml` | Yes, `30m` | PDF tools |
| **Omni Tools** | `${PUBLIC_SCHEME}://omni.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/omni-tools.yml` | Yes, `30m` | general utilities |
| **VERT** | `${PUBLIC_SCHEME}://vert.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/vert.yml` | Yes, `30m` | browser-side file conversion |
| **Speedtest Tracker** | `${PUBLIC_SCHEME}://speed.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/speedtest-tracker.yml` | Yes, `15m` | stores SQLite data under `/config`; `speedtest-trigger` wakes it hourly through the API |
| **DumbAssets** | `${PUBLIC_SCHEME}://assets.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/dumbassets.yml` | Yes, `30m` | tracks assets, warranties, receipts, manuals, and maintenance |

---

## App Stacks

### Karakeep stack

| Service | Access | Profile(s) | Sleep | Notes |
|---|---|---|---|---|
| **keep** | `${PUBLIC_SCHEME}://keep.${DOMAIN}` | `apps`, `all` | Yes, `15m` | file-provider route in `config/traefik/dyn/keep.yml` |
| `chrome` | internal only | `apps`, `all` | No | browser worker |
| `meilisearch` | internal only | `apps`, `all` | No | search backend |

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
| **listmonk** | `${PUBLIC_SCHEME}://listmonk.${DOMAIN}` | `apps`, `all` | No in current routing | route file is `config/traefik/dyn/listmonk.yml` |
| `listmonk-postgres` | internal only | `apps`, `all` | No | app-local PostgreSQL |
| `cftunnel` | internal only | `tunnel` | No | optional sidecar |

Required var: `LISTMONK_DB_PASSWORD`

### Immich stack

| Service | Access | Profile(s) | Sleep | Notes |
|---|---|---|---|---|
| **immich-server** | `${PUBLIC_SCHEME}://photos.${DOMAIN}` | `apps`, `all` | No | Docker-label route in `services/apps/immich.yml` |
| `immich-microservices` | internal only | `apps`, `all` | No | background workers |
| `immich-machine-learning` | internal only | `apps`, `all` | No | ML service |
| `redis` | internal only | `apps`, `all` | No | queue/cache |
| `immich-postgres` | internal only | `apps`, `all` | No | app-local PostgreSQL |

Required var: `IMMICH_DB_PASSWORD`

### Paperless-ngx stack

| Service | Access | Profile(s) | Sleep | Notes |
|---|---|---|---|---|
| **paperless-web** | `${PUBLIC_SCHEME}://paper.${DOMAIN}` | `apps`, `all` | Yes, `15m` | route file is `config/traefik/dyn/paperless.yml` |
| `paperless-consumer` | internal only | `apps`, `all` | No | background consumer |
| `paperless-postgres` | internal only | `apps`, `all` | No | app-local PostgreSQL |
| `paperless-redis` | internal only | `apps`, `all` | No | Redis |
| `paperless-gotenberg` | internal only | `apps`, `all` | No | document conversion |
| `paperless-tika` | internal only | `apps`, `all` | No | document parsing |

Required vars:

- `PAPERLESS_DBPASS`
- `PAPERLESS_ADMIN_PASSWORD`
- `PAPERLESS_SECRET_KEY`

### Media stack

| Service | Access | Profile(s) | Routing source | Sleep | Notes |
|---|---|---|---|---|---|
| **Jellyfin** | `${PUBLIC_SCHEME}://jellyfin.${DOMAIN}` | `apps`, `all` | Docker labels on `jellyfin` | No | media server |
| **Seerr** | `${PUBLIC_SCHEME}://requests.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/seerr.yml` | Yes, `30m` | request UI |
| **Immich Power Tools** | `${PUBLIC_SCHEME}://immich-tools.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/immich-power-tools.yml` | Yes, `30m` | separate helper app, not core Immich routing |
| **torrent** | `${PUBLIC_SCHEME}://torrent.${DOMAIN}` | `apps`, `all` | Docker labels on `gluetun` | No | qBittorrent service name is `torrent`; shares `gluetun` network namespace |
| **Sonarr** | `${PUBLIC_SCHEME}://sonarr.${DOMAIN}` | `apps`, `all` | Docker labels on `gluetun` | No | shares `gluetun` network namespace |
| **Radarr** | `${PUBLIC_SCHEME}://radarr.${DOMAIN}` | `apps`, `all` | Docker labels on `gluetun` | No | shares `gluetun` network namespace |
| **Byparr** | internal only, `http://byparr:8191` from `media` | `apps`, `all` | None | No | FlareSolverr-compatible helper; shares `gluetun` network namespace |
| **Prowlarr** | `${PUBLIC_SCHEME}://prowlarr.${DOMAIN}` | `apps`, `all` | Docker labels | No | indexer management for the media stack |
| **Bazarr** | `${PUBLIC_SCHEME}://bazarr.${DOMAIN}` | `apps`, `all` | Docker labels on `bazarr` | No | subtitle management for the shared media library |

Current caveat:

- `gluetun` now carries the routed network path for `torrent`, `sonarr`, `radarr`, and `byparr`
- `gluetun` also carries `torrent`, `sonarr`, `radarr`, and `byparr` aliases on `media` to preserve internal service-name reachability
- configure Prowlarr's FlareSolverr indexer proxy host as `http://byparr:8191`, not `/v1`; Prowlarr appends `/v1`
- active compose requires `OPENVPN_USER` and `OPENVPN_PASSWORD` for Gluetun; `setup-dev.sh` writes local dummy values so config rendering works
- replace the dummy OpenVPN values before running VPN-backed downloads for real
- `VPN_SERVER_COUNTRIES` is optional and defaults to `Netherlands`

### Home Assistant

| Service | Access | Profile(s) | Routing source | Sleep | Notes |
|---|---|---|---|---|---|
| **ha** | `${PUBLIC_SCHEME}://ha.${DOMAIN}` | `apps`, `all`, `service` | `config/traefik/dyn/ha.yml` | No | host-networked; files live under `home-assistant/` |

Narrow start command:

```bash title="Start only Home Assistant"
$ docker compose --profile service up -d ha
[+] Running 1/1
 ✔ Container homelab-ha-1  Started
```

---

## Required Variables

These are the variables that matter for the active stack.

| Variable | Used by |
|---|---|
| `RUSTFS_ACCESS_KEY` | **RustFS** |
| `RUSTFS_SECRET_KEY` | **RustFS** |
| `IMMICH_DB_PASSWORD` | **Immich**, **Immich Power Tools** |
| `LISTMONK_DB_PASSWORD` | **Listmonk** |
| `PAPERLESS_DBPASS` | **Paperless-ngx** |
| `PAPERLESS_ADMIN_PASSWORD` | **Paperless-ngx** |
| `PAPERLESS_SECRET_KEY` | **Paperless-ngx** |
| `NEXTAUTH_SECRET` | **Karakeep** |
| `MEILI_MASTER_KEY` | **Karakeep**, **Meilisearch** |
| `SPEEDTEST_APP_KEY` | **Speedtest Tracker** |
| `SPEEDTEST_API_TOKEN` | **Speedtest Trigger** sidecar; create it in Speedtest Tracker with `Read Results` and `Run Speedtest` abilities |
| `OPENVPN_USER` | **Gluetun** ProtonVPN OpenVPN username |
| `OPENVPN_PASSWORD` | **Gluetun** ProtonVPN OpenVPN password |
| `DUMBASSETS_PIN` | **DumbAssets** |
| `DUMBASSETS_SESSION_SECRET` | **DumbAssets** |

Bootstrap behavior:

- `.env.example` already provides local RustFS defaults.
- `setup-dev.sh` auto-generates `IMMICH_DB_PASSWORD`, `LISTMONK_DB_PASSWORD`, `PAPERLESS_DBPASS`, `PAPERLESS_SECRET_KEY`, `NEXTAUTH_SECRET`, `MEILI_MASTER_KEY`, `SPEEDTEST_APP_KEY`, and `DUMBASSETS_SESSION_SECRET` when they are missing.
- `setup-dev.sh` writes dummy `OPENVPN_USER`, `OPENVPN_PASSWORD`, and `DUMBASSETS_PIN` values for local config rendering. Real Gluetun use still needs real VPN credentials.
- In CI only, `setup-dev.sh` also writes dummy `ACME_EMAIL`, `CF_DNS_API_TOKEN`, and `PAPERLESS_ADMIN_PASSWORD` values so the production HTTPS render can be checked without real secrets.
- For local full-stack runs, set `PAPERLESS_ADMIN_PASSWORD` yourself unless you already provide it through the environment.
- For production HTTPS, also set `PUBLIC_SCHEME=https`, `TRAEFIK_ENTRYPOINT=websecure`, `TRAEFIK_STATIC_CONFIG=../../config/traefik/traefik.acme.yml`, `ACME_EMAIL`, and `CF_DNS_API_TOKEN`.

---

## Parked Definitions

These service files exist but are not active because the root include list does not reference them:

- `services/parked/hermes.yml`

Historical Teable Swarm fragments are retained as examples:

- `docs/examples/teable.yml`
- `docs/examples/teable-migrate.yml`
