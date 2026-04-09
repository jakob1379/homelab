# Service Reference

This page lists every service, its purpose, and how to access it. If you need the system model first, read [Architecture](architecture.md). For deployment and changes, use [Configuration](customization.md) and [Portainer GitOps](portainer.md).

## Try It Now

Start with these three services:

1. **Traefik** (included in `infra`), the traffic director
2. **Portainer**, Docker management UI
3. **IT Tools**, Developer utilities

```bash
$ docker compose --profile infra up -d
[+] Running 6/6
 ✔ Container homelab-traefik-1  Started
 ...

$ docker compose --profile apps up -d portainer ittools
[+] Running 2/2
 ✔ Container homelab-portainer-1  Started
 ✔ Container homelab-ittools-1    Started
```

Then open `https://pods.${DOMAIN}` and `https://it.${DOMAIN}`.

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
- **Access:** `https://rustfs.${DOMAIN}` (API), `https://rustfs-console.${DOMAIN}` (UI)
- **Profile:** infra
- **Env:** `.env-rustfs` (access/secret keys)
- **Sablier:** No (always on for backup/automation reliability)
- **Homepage link:** points to `https://rustfs-console.${DOMAIN}` (admin UI)

### AdGuard Home
- **Purpose:** Network-wide ad blocker & DNS
- **Access:** Port `${ADGUARD_DNS_PORT}` (default `1053`) + `https://dns.${DOMAIN}`
- **Profile:** infra
- **Ports:** `${ADGUARD_DNS_PORT}:53/tcp`, `${ADGUARD_DNS_PORT}:53/udp`
- **Note:** If DNS is routed through a VPN sidecar network (for example NetBird), you can remove host DNS port publishing.

### NetAlertX
- **Purpose:** Network device scanner & alerts
- **Access:** `http://localhost:20211`
- **Profile:** infra
- **Network:** host mode
- **Env:** `.env-netalertx`
- **Security:** Read-only root filesystem with minimal Linux caps (`CHOWN`, `SETGID`, `SETUID`, `NET_ADMIN`, `NET_RAW`, `NET_BIND_SERVICE`)

## Application Services

### Portainer
- **Purpose:** Docker container management UI
- **Access:** `https://pods.${DOMAIN}`
- **Profile:** apps
- **Sablier:** Yes
- **Notes:** Has built-in authentication
- **Guide:** [Portainer GitOps](portainer.md)

### Karakeep
- **Purpose:** Bookmark manager with AI tagging
- **Access:** `https://keep.${DOMAIN}`
- **Profile:** apps
- **Env:** `.env-karakeep`
- **Sablier:** Yes
- **Dependencies:** Chrome, Meilisearch
- **Sleep behavior:** `keep`, `chrome`, and `meilisearch` share one Sablier group and sleep together after 15 minutes of inactivity

### Listmonk
- **Purpose:** Newsletter & mailing list manager
- **Access:** `https://listmonk.${DOMAIN}`
- **Profile:** apps
- **Env:** `.env-listmonk`
- **Sablier:** Yes
- **Dependencies:** `listmonk-postgres`
- **Extras:** Optional Cloudflare tunnel (`cftunnel`) via `--profile tunnel`

### Homepage
- **Purpose:** Service dashboard with quick links to all services
- **Access:** `https://home.${DOMAIN}`
- **Profile:** apps
- **Sablier:** No (always running for dashboard access)
- **Notes:** Auto-discovers services via Docker labels

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

### Dozzle
- **Purpose:** Real-time Docker log viewer
- **Access:** `https://dozzle.${DOMAIN}`
- **Profile:** apps
- **Sablier:** Yes

### BentoPDF
- **Purpose:** PDF manipulation tools
- **Access:** `https://pdf.${DOMAIN}`
- **Profile:** apps
- **Env:** `.env-bentopdf`
- **Sablier:** Yes

### Immich
- **Purpose:** Photo and video management with AI features
- **Access:** `https://photos.${DOMAIN}`
- **Profile:** apps
- **Env:** `.env-immich`
- **Sablier:** Partial (API/UI always on; workers can be queue-woken)
- **Notes:** `immich-server` is routed by `config/traefik/dyn/immich.yml` at `photos.${DOMAIN}`; `immich-microservices` and `immich-machine-learning` are grouped as `immich-workers`
- **Notes:** Queue-based wake logic is experimental via profile `experimental` (not included in `all`)
- **Dependencies:** `immich-postgres`, `redis`
- **Enable experimental mode:** `docker compose --profile all --profile experimental up -d`

### Paperless-ngx
- **Purpose:** Document management system with OCR and full-text search
- **Access:** `https://paperless.${DOMAIN}`
- **Profile:** apps
- **Env:** `.env-paperless`
- **Sablier:** Yes
- **Dependencies:** `paperless-postgres`, `paperless-redis`, `paperless-gotenberg` (PDF conversion), `paperless-tika` (document parsing)
- **Notes:** Supports document upload, OCR, tagging, and full-text search. Configure OCR language in `.env-paperless`

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
| Portainer | `pods` |
| CloudBeaver | `cbeaver` |
| BentoPDF | `pdf` |
| Immich | `photos` |
| Paperless-ngx | `paperless` |
| Jellyfin | `jellyfin` |
| Seerr | `requests` |
| Dozzle | `dozzle` |
| Karakeep | `keep` |
| Listmonk | `listmonk` |
| Omni Tools | `omni` |
| RustFS API | `rustfs` |
| RustFS Console | `rustfs-console` |
| Home Assistant | `ha` |
| AdGuard | `dns` |
| NetAlertX | N/A (port 20211) |

## Environment Files Reference

| File | Service | Contents |
|------|---------|----------|
| `.env-listmonk` | Listmonk | DB credentials, app settings |
| `.env-karakeep` | Karakeep | MeiliSearch key, admin password |
| `.env-bentopdf` | BentoPDF | PDF processing options |
| `.env-immich` | Immich | Database credentials |
| `.env-rustfs` | RustFS | S3 access/secret keys |
| `.env-netalertx` | NetAlertX | Scan subnets, notifications |
| `.env-paperless` | Paperless-ngx | OCR language, admin credentials, secret key |

## Secrets Reference

| File | Used By | Purpose |
|------|---------|---------|
| `cf_dns_api_token` | Traefik | Cloudflare DNS-01 challenge |
