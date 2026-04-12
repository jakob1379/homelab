# Service Reference

This page lists every service, its purpose, and how to access it. If you need the system model first, read [Architecture](architecture.md). For deployment and changes, use [Configuration](customization.md) and [Deployment](dockhand.md).

## Try It Now

Start with these three services:

1. **Traefik** (included in `infra`), the traffic director
2. **Dockhand**, Docker management UI
3. **IT Tools**, Developer utilities

```bash title="Start a minimal sample set"
$ docker compose --profile infra up -d
[+] Running 6/6
 ✔ Container homelab-traefik-1  Started
 ...

$ docker compose --profile apps up -d ittools
[+] Running 1/1
  ✔ Container homelab-ittools-1    Started

$ docker compose -f docker-compose.pods.yml up -d
[+] Running 1/1
  ✔ Container homelab-pods-dockhand-1  Started
```

Then open `https://docker.${DOMAIN}` and `https://it.${DOMAIN}`.

---

Complete list of services and configuration points.

## Infrastructure Services

### Traefik: The Traffic Director
- **What it does:** Sits at the edge of your homelab. It receives requests for `photos.yourdomain.com`, forwards them to the right container, and handles HTTPS certificates.
- **Access:** `https://traefik.${DOMAIN}`
- **Profile:** infra
- **Ports:** 80, 443
- **Config:** `config/traefik/traefik.yml`

### Sablier: Sleep Controller
- **What it does:** Stops sleep-enabled apps when idle and wakes them on request in about 2 seconds. Services not wired to Sablier (for example, Immich API/UI) stay running.
- **Why it matters:** It reduces idle resource usage.
- **Profile:** infra
- **Network:** traefik_public

### App-Local Databases
- **What it does:** Each stateful app owns its database container. This avoids cross-app coupling and removes shared DB bootstrap logic.
- **Services:** `immich-postgres`, `listmonk-postgres`, `paperless-postgres`
- **Profile:** apps
- **Network:** Each database stays on its app network only (`immich`, `listmonk`, `paperless`)

### RustFS
- **Purpose:** S3-compatible object storage
- **Access:** `https://rustfs.${DOMAIN}` (UI), `https://rustfs-api.${DOMAIN}` (API)
- **Profile:** infra
- **Required env:** `RUSTFS_ACCESS_KEY`, `RUSTFS_SECRET_KEY`
- **Sablier:** No (always on for backup/automation reliability)
- **Homepage link:** points to `https://rustfs.${DOMAIN}` (admin UI)

### AdGuard Home
- **Purpose:** Network-wide ad blocker & DNS
- **Access:** Port `${ADGUARD_DNS_PORT}` (default `1053`) + `https://dns.${DOMAIN}`
- **Profile:** infra
- **Ports:** `${ADGUARD_DNS_PORT}:53/tcp`, `${ADGUARD_DNS_PORT}:53/udp`
- **Note:** If DNS is routed through a VPN sidecar network (for example NetBird), you can remove host DNS port publishing.

### NetAlertX
- **Purpose:** Network device scanner & alerts
- **Access:** `https://netalertx.${DOMAIN}` (`http://localhost:20211` still works directly on the host)
- **Profile:** infra
- **Network:** host mode
- **Defaults in compose:** `NETALERTX_SCAN_SUBNETS=192.168.1.0/24`, override via `.env` if needed
- **Security:** Read-only root filesystem with minimal Linux caps (`CHOWN`, `SETGID`, `SETUID`, `NET_ADMIN`, `NET_RAW`, `NET_BIND_SERVICE`)

## Application Services

### Dockhand
- **Purpose:** Modern Docker management UI
- **Access:** `https://docker.${DOMAIN}` after the full deploy, or `http://localhost:3000` from the separate bootstrap stack
- **Stack:** `docker-compose.pods.yml`; after the main deploy, Traefik routes `docker.${DOMAIN}` to that separate stack
- **Sablier:** Yes
- **Notes:** Mounts the local Docker socket, stores stack data on a matching host path via `DOCKHAND_DATA_DIR`, and publishes a direct bootstrap port on `3000`

### Karakeep
- **Purpose:** Bookmark manager with AI tagging
- **Access:** `https://keep.${DOMAIN}`
- **Profile:** apps
- **Required env:** `NEXTAUTH_SECRET`, `MEILI_MASTER_KEY`
- **Sablier:** Yes
- **Dependencies:** Chrome, Meilisearch
- **Sleep behavior:** `keep`, `chrome`, and `meilisearch` share one Sablier group and sleep together after 15 minutes of inactivity

### Listmonk
- **Purpose:** Newsletter & mailing list manager
- **Access:** `https://listmonk.${DOMAIN}`
- **Profile:** apps
- **Required env:** `LISTMONK_db__password`
- **Sablier:** Yes
- **Dependencies:** `listmonk-postgres`
- **Extras:** Optional Cloudflare tunnel (`cftunnel`) via `--profile tunnel`

### Homepage
- **Purpose:** Service dashboard with quick links to all services
- **Access:** `https://home.${DOMAIN}`
- **Profile:** apps
- **Sablier:** Yes
- **Notes:** Auto-discovers services via Docker labels and uses the `home` Sablier group

### AnythingLLM
- **Purpose:** Private AI workspace for chat, document Q&A, and agent tooling
- **Access:** `https://llm.${DOMAIN}`
- **Profile:** apps
- **Sablier:** Yes
- **Recommended host baseline:** 2 GB RAM, 2 CPU cores, 5 GB storage
- **Notes:** Uses the official Docker image with persistent storage at `/app/server/storage`
- **Notes:** Keeps `SYS_ADMIN` for upstream Docker compatibility with browser-backed features
- **Notes:** Includes `host.docker.internal` mapping so host-run services such as Ollama can be reached from the container

### Jellyfin
- **Purpose:** Media server for movies and shows
- **Access:** `https://jellyfin.${DOMAIN}`
- **Profile:** apps
- **Sablier:** Yes
- **Service port:** 8096
- **Volumes:** `jellyfin_config`, `jellyfin_cache`, shared `media_data` (`/data`)

### Seerr
- **Purpose:** Request portal for on-demand movies and shows
- **Access:** `https://requests.${DOMAIN}`
- **Profile:** apps
- **Sablier:** Yes
- **Dependencies:** Integrates with Jellyfin + Sonarr + Radarr (use `gluetun` as host for Sonarr/Radarr in Seerr)

### Media Automation (Internal)
- **Purpose:** Fetch and import requested content into Jellyfin libraries
- **Services:** `gluetun`, `qbittorrent`, `sonarr`, `radarr`
- **Profile:** apps
- **Network:** Internal `media` network only (not exposed via Traefik)
- **Path model:** Single shared root mount `media_data:/data` across downloader and Arr apps for reliable imports/hardlinks
- **Privacy model:** `qbittorrent`, `sonarr`, and `radarr` share Gluetun's network namespace so all outbound download/indexer traffic exits through ProtonVPN
- **Required env:** Set `OPENVPN_USER` and `OPENVPN_PASSWORD` in `.env` (optionally `VPN_SERVER_COUNTRIES`) before enabling on-demand downloading

## Developer Tools

### IT Tools
- **Purpose:** 50+ dev utilities (formatters, converters, etc.)
- **Access:** `https://it.${DOMAIN}`
- **Profile:** apps
- **Sablier:** Yes

### Omni Tools
- **Purpose:** Collection of 100+ web-based utilities (converters, generators, parsers)
- **Access:** `https://omni.${DOMAIN}`
- **Profile:** apps
- **Sablier:** Yes

### CloudBeaver
- **Purpose:** Web-based database management
- **Access:** `https://cbeaver.${DOMAIN}`
- **Profile:** apps
- **Sablier:** Yes
- **Notes:** Has built-in authentication

### BentoPDF
- **Purpose:** PDF manipulation tools
- **Access:** `https://pdf.${DOMAIN}`
- **Profile:** apps
- **Sablier:** Yes

### Speedtest Tracker
- **Purpose:** Track internet speed, latency, and uptime over time
- **Access:** `https://speed.${DOMAIN}`
- **Profile:** apps
- **Required env:** `SPEEDTEST_APP_KEY` (for example via `.envrc`)
- **Sablier:** Yes
- **Storage:** `speedtest_tracker_data` named volume with SQLite in `/config`

### VERT
- **Purpose:** Browser-based local file converter using WebAssembly
- **Access:** `https://vert.${DOMAIN}`
- **Profile:** apps
- **Sablier:** Yes
- **Notes:** Follows the upstream container defaults; browser-local conversions work directly and optional hosted video conversion can use VERT's default backend

### Immich
- **Purpose:** Photo and video management with AI features
- **Access:** `https://photos.${DOMAIN}`
- **Profile:** apps
- **Required env:** `IMMICH_DB_PASSWORD`
- **Sablier:** Partial (API/UI and ML always on; only `immich-microservices` is queue-woken)
- **Notes:** `immich-server` is routed by `config/traefik/dyn/immich.yml` at `photos.${DOMAIN}`; the real wake path is `immich-queue-monitor` calling Sablier for `immich-workers`
- **Notes:** `immich-queue-monitor` starts with the Immich stack under the standard `apps` and `all` profiles
- **Dependencies:** `immich-postgres`, `redis`

### Paperless-ngx
- **Purpose:** Document management system with OCR and full-text search
- **Access:** `https://paper.${DOMAIN}`
- **Profile:** apps
- **Required env:** `PAPERLESS_DBPASS`, `PAPERLESS_ADMIN_PASSWORD`, `PAPERLESS_SECRET_KEY`
- **Sablier:** Yes
- **Dependencies:** `paperless-postgres`, `paperless-redis`, `paperless-gotenberg` (PDF conversion), `paperless-tika` (document parsing)
- **Notes:** Supports document upload, OCR, tagging, and full-text search. `PAPERLESS_OCR_LANGUAGE` defaults to `eng` in compose

### Whoami
- **Purpose:** Debug endpoint (shows request info)
- **Access:** `https://whoami.${DOMAIN}`
- **Profile:** infra
- **Sablier:** Yes

### Home Assistant (Standalone)
- **Purpose:** Home automation and device control
- **Access:** `https://ha.${DOMAIN}`
- **Compose file:** `home-assistant/docker-compose.yml`
- **Start command:** `cd home-assistant && docker compose --profile service up -d`
- **Config storage:** Docker named volume `ha_config` mounted at `/config`

## URL Patterns

All services follow: `https://<subdomain>.${DOMAIN}`

| Service | Subdomain |
|---------|-----------|
| Traefik Dashboard | `traefik` |
| Whoami | `whoami` |
| IT Tools | `it` |
| AnythingLLM | `llm` |
| Dockhand | `docker` |
| CloudBeaver | `cbeaver` |
| BentoPDF | `pdf` |
| Speedtest Tracker | `speed` |
| VERT | `vert` |
| Immich | `photos` |
| Paperless-ngx | `paper` |
| Jellyfin | `jellyfin` |
| Seerr | `requests` |
| Karakeep | `keep` |
| Listmonk | `listmonk` |
| Omni Tools | `omni` |
| RustFS | `rustfs` |
| RustFS API | `rustfs-api` |
| Home Assistant | `ha` |
| AdGuard | `dns` |
| NetAlertX | `netalertx` |

## Required Variables Reference

| Variable | Service | Purpose |
|----------|---------|---------|
| `ACME_EMAIL` | Traefik | Let's Encrypt ACME contact email |
| `CF_DNS_API_TOKEN` | Traefik | Cloudflare DNS-01 challenge token |
| `IMMICH_DB_PASSWORD` | Immich | PostgreSQL password |
| `LISTMONK_db__password` | Listmonk | PostgreSQL password |
| `PAPERLESS_DBPASS` | Paperless-ngx | PostgreSQL password |
| `PAPERLESS_ADMIN_PASSWORD` | Paperless-ngx | Initial admin password |
| `PAPERLESS_SECRET_KEY` | Paperless-ngx | Django app secret |
| `NEXTAUTH_SECRET` | Karakeep | Auth/session secret |
| `MEILI_MASTER_KEY` | Karakeep / Meilisearch | Shared search API key |
| `RUSTFS_ACCESS_KEY` | RustFS | S3 access key |
| `RUSTFS_SECRET_KEY` | RustFS | S3 secret key |
| `OPENVPN_USER` | Gluetun | ProtonVPN OpenVPN username |
| `OPENVPN_PASSWORD` | Gluetun | ProtonVPN OpenVPN password |
| `SPEEDTEST_APP_KEY` | Speedtest Tracker | Laravel app key |

## TLS / DNS Credentials

| Variable | Used By | Purpose |
|----------|---------|---------|
| `ACME_EMAIL` | Traefik | Let's Encrypt ACME contact email |
| `CF_DNS_API_TOKEN` | Traefik | Cloudflare DNS-01 challenge |
