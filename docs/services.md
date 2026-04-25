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

# 2. Start one sleeping app and one direct-label app
$ docker compose --profile apps up -d keep speedtest-tracker
[+] Running ...
 ✔ Container homelab-keep-1               Started
 ✔ Container homelab-speedtest-tracker-1  Started

# 3. Verify both routes
$ curl -k https://keep.traefik.me
<!doctype html>
...

$ curl -k https://speed.traefik.me
<!DOCTYPE html>
...
```

`keep` goes through a file-provider **Sablier** route. `speedtest-tracker` uses direct Docker labels.

---

## Bootstrap Control Plane

| Service | Access | Compose file | Sleep | Notes |
|---|---|---|---|---|
| **Dockhand** | `http://localhost:3000` during bootstrap, `https://docker.${DOMAIN}` after the main stack is up | `services/pods.yml` via `docker-compose.pods.yml` | No | separate stack on shared `traefik_public` |

---

## Foundation Services

| Service | Access | Profile(s) | Routing source | Sleep | Notes |
|---|---|---|---|---|---|
| **Traefik** | `https://traefik.${DOMAIN}` | `infra`, `all` | Docker labels | No | reverse proxy and dashboard |
| **Sablier** | internal only | `infra`, `all` | none | No | Docker provider for sleep-on-request |
| **whoami** | `https://whoami.${DOMAIN}` | `infra`, `all` | `config/traefik/dyn/whoami.yml` | Yes, `10m` | uses `sablier-default@file` |
| **RustFS** | `https://rustfs.${DOMAIN}`, `https://rustfs-api.${DOMAIN}` | `infra`, `all` | `config/traefik/dyn/rustfs.yml` | No | object storage and console |
| **AdGuard Home** | `https://dns.${DOMAIN}` and host DNS port `${ADGUARD_DNS_PORT}` | `infra`, `all` | Docker labels | No | publishes port `53` on the configured host port |
| **NetAlertX** | `https://netalertx.${DOMAIN}` | `infra`, `all` | `config/traefik/dyn/netalertx.yml` | No | service itself runs in `network_mode: host` |

---

## Utilities And Dashboards

| Service | Access | Profile(s) | Routing source | Sleep | Notes |
|---|---|---|---|---|---|
| **Homepage** | `https://home.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/home.yml` | Yes, `30m` | auto-discovers most entries from Docker labels |
| **AnythingLLM** | `https://llm.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/anythingllm.yml` | Yes, `30m` | keeps `SYS_ADMIN` and `host.docker.internal` mapping |
| **IT Tools** | `https://it.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/ittools.yml` | Yes, `30m` | developer utilities |
| **CloudBeaver** | `https://cbeaver.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/cbeaver.yml` | Yes, `30m` | DB UI |
| **BentoPDF** | `https://pdf.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/bentopdf.yml` | Yes, `30m` | PDF tools |
| **Omni Tools** | `https://omni.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/omni-tools.yml` | Yes, `30m` | general utilities |
| **VERT** | `https://vert.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/vert.yml` | Yes, `30m` | browser-side file conversion |
| **Speedtest Tracker** | `https://speed.${DOMAIN}` | `apps`, `all` | Docker labels | No | stores SQLite data under `/config` |

---

## App Stacks

### Karakeep stack

| Service | Access | Profile(s) | Sleep | Notes |
|---|---|---|---|---|
| **keep** | `https://keep.${DOMAIN}` | `apps`, `all` | Yes, `15m` | file-provider route in `config/traefik/dyn/keep.yml` |
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
| **listmonk** | `https://listmonk.${DOMAIN}` | `apps`, `all` | No in current routing | route file is `config/traefik/dyn/listmonk.yml` |
| `listmonk-postgres` | internal only | `apps`, `all` | No | app-local PostgreSQL |
| `cftunnel` | internal only | `tunnel` | No | optional sidecar |

Required var: `LISTMONK_db__password`

### Immich stack

| Service | Access | Profile(s) | Sleep | Notes |
|---|---|---|---|---|
| **immich-server** | `https://photos.${DOMAIN}` | `apps`, `all` | No | Docker-label route in `services/immich.yml` |
| `immich-microservices` | internal only | `apps`, `all` | No | background workers |
| `immich-machine-learning` | internal only | `apps`, `all` | No | ML service |
| `redis` | internal only | `apps`, `all` | No | queue/cache |
| `immich-postgres` | internal only | `apps`, `all` | No | app-local PostgreSQL |

Required var: `IMMICH_DB_PASSWORD`

### Paperless-ngx stack

| Service | Access | Profile(s) | Sleep | Notes |
|---|---|---|---|---|
| **paperless-web** | `https://paper.${DOMAIN}` | `apps`, `all` | Yes, `15m` | route file is `config/traefik/dyn/paperless.yml` |
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
| **Jellyfin** | `https://jellyfin.${DOMAIN}` | `apps`, `all` | Docker labels on `jellyfin` | No | media server |
| **Seerr** | `https://requests.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/seerr.yml` | Yes, `30m` | request UI |
| **Immich Power Tools** | `https://immich-tools.${DOMAIN}` | `apps`, `all` | `config/traefik/dyn/immich-power-tools.yml` | Yes, `30m` | separate helper app, not core Immich routing |
| **torrent** | `https://torrent.${DOMAIN}` | `apps`, `all` | Docker labels on `gluetun` | No | qBittorrent service name is `torrent`; shares `gluetun` network namespace |
| **Sonarr** | `https://sonarr.${DOMAIN}` | `apps`, `all` | Docker labels on `gluetun` | No | shares `gluetun` network namespace |
| **Radarr** | `https://radarr.${DOMAIN}` | `apps`, `all` | Docker labels on `gluetun` | No | shares `gluetun` network namespace |
| **Prowlarr** | `https://prowlarr.${DOMAIN}` | no explicit profile | Docker labels | No | starts by default in the main stack because it has no profile |

Current caveat:

- `gluetun` now carries the routed network path for `torrent`, `sonarr`, and `radarr`
- `gluetun` also carries `torrent`, `sonarr`, and `radarr` aliases on `media` to preserve internal service-name reachability
- `setup-dev.sh` requires `OPENVPN_USER` and `OPENVPN_PASSWORD` for `--profile apps` and `--profile all`
- `VPN_SERVER_COUNTRIES` is optional and defaults to `Netherlands`

### Home Assistant

| Service | Access | Profile(s) | Routing source | Sleep | Notes |
|---|---|---|---|---|---|
| **ha** | `https://ha.${DOMAIN}` | `apps`, `all`, `service` | Docker labels | No | files live under `home-assistant/` |

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
| `ACME_EMAIL` | **Traefik** |
| `CF_DNS_API_TOKEN` | **Traefik** |
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

---

## Parked Definitions

These service files exist but are not active because the root include list does not reference them:

- `services/hermes.yml`
- `services/teable.yml`
- `services/teable-migrate.yml`
