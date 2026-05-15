# Homelab

[![CI](https://github.com/jakob1379/homelab/actions/workflows/test-docker-compose.yml/badge.svg)](https://github.com/jakob1379/homelab/actions/workflows/test-docker-compose.yml)
[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-Ready-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![Traefik](https://img.shields.io/badge/Traefik-Proxy-24A1C1?logo=traefikproxy&logoColor=white)](https://traefik.io/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **Docker Compose homelab with two entrypoints.** `docker-compose.yml` runs the main stack. `docker-compose.pods.yml` boots **Dockhand** as the separate control plane.

This repo defaults to local HTTPS routing through **Traefik** at `https://<service>.localhost.me` using mkcert-generated local certificates. Production ACME certificates are handled by the alternate Cloudflare DNS-01 Traefik config.

---

## Try It Now (2 Minutes)

Start the bootstrap control plane first. This works without touching the main stack.

```bash title="Bootstrap Dockhand only"
# 1. Clone the repo
$ git clone https://github.com/jakob1379/homelab.git && cd homelab
Cloning into 'homelab'...
done.

# 2. Start the separate Dockhand stack
$ docker compose -f docker-compose.pods.yml up -d
[+] Running 1/1
 ✔ Container homelab-pods-dockhand-1  Started

# 3. Verify the direct bootstrap endpoint
$ curl -I http://localhost:3000
HTTP/1.1 200 OK
```

Open `http://localhost:3000`.

If you want the full routed stack, keep going.

---

## Start The Main Stack

`setup-dev.sh` is the local source of truth for required variables and generated development keys.

```bash title="Prepare local env and inspect missing values"
# 1. Prepare .env from .env.example when needed
$ ./setup-dev.sh
[INFO] Setting up the homelab development environment...
[INFO] setup-dev.sh generates local TLS files and app keys, sets local OpenVPN placeholders, and leaves optional service env overrides optional
[INFO] Set development placeholder: OPENVPN_USER
[INFO] Set development placeholder: OPENVPN_PASSWORD
[INFO] Generated development key: NEXTAUTH_SECRET
[INFO] Generated development key: MEILI_MASTER_KEY
[WARN] Missing required variables for docker compose --profile all:
 - PAPERLESS_ADMIN_PASSWORD
 ...
[INFO] Setup complete!
```

`setup-dev.sh` writes dummy OpenVPN values so the local full stack can render and expose the media UIs. Replace them and set `GLUETUN_HEALTHCHECK_DISABLED=false` before running the VPN-backed media automation for real.

Fill the values you actually need, then start the full stack or the profiles you want.

```bash title="Start the full stack"
# 2. Add the required values to .env
$ cat >> .env <<'EOF'
PAPERLESS_ADMIN_PASSWORD=change-me
EOF

# 3. Start the full local stack and wait for health checks
$ docker compose --profile all up --wait
[+] Running ...
 ✔ Container homelab-traefik-1   Started
 ✔ Container homelab-sablier-1   Started
 ✔ Container homelab-rustfs-1    Started

# 4. Verify a routed endpoint
$ curl https://whoami.localhost.me
Hostname: homelab-whoami-1
IP: 172.20.0.2
```

!!! note
    Use service subdomains such as `https://whoami.localhost.me` or `https://traefik.localhost.me`. A request to plain `https://localhost.me` will not match a Traefik router.

---

## How The Repo Is Laid Out Now

### `docker-compose.yml`: main stack

This file includes the active stack definitions under `services/` plus `home-assistant/docker-compose.yml`.

```yaml title="docker-compose.yml"
include:
  - services/networking.yml
  - services/rustfs.yml
  - services/tools.yml
  - services/omni-tools.yml
  - services/speedtest-tracker.yml
  - services/vert.yml
  - services/anythingllm.yml
  - services/listmonk.yml
  - services/karakeep.yml
  - services/immich.yml
  - services/paperless-ngx.yml
  - services/media.yml
  - services/homepage.yml
  - home-assistant/docker-compose.yml
```

### `docker-compose.pods.yml`: bootstrap stack

This file includes only `services/pods.yml`.

```yaml title="docker-compose.pods.yml"
include:
  - services/pods.yml
```

### Active profiles

| Profile | Purpose |
|---|---|
| `infra` | Always-on foundation services |
| `apps` | Most application services |
| `all` | Convenience profile for the full main stack |
| `tunnel` | Optional `cftunnel` sidecar for Listmonk |
| `service` | Narrow profile currently used by Home Assistant |

`home-assistant/docker-compose.yml` puts `ha` in `profiles: [apps, all, service]`.

---

## What Is Actually Routed

The routing model is split.

### File-provider routes in `config/traefik/dyn/*.yml`

These are the routes that currently use explicit **Traefik** file-provider config, usually because they also need **Sablier** middleware:

- **AnythingLLM**
- **BentoPDF**
- **CloudBeaver**
- **Homepage**
- **Home Assistant**
- **Immich Power Tools**
- **IT Tools**
- **Jellyfin**
- **Karakeep**
- **Listmonk**
- **NetAlertX**
- **Omni Tools**
- **Paperless-ngx**
- **RustFS**
- **Seerr**
- **Speedtest Tracker**
- **VERT**
- **whoami**

### Direct Docker-label routes

These are currently routed with service labels instead of `config/traefik/dyn/*.yml`:

- **AdGuard**
- **Dockhand**
- **Immich**
- **Prowlarr**
- **Bazarr**
- **Radarr**
- **Sonarr**
- **torrent** (`https://torrent.${DOMAIN}`)
- **Traefik dashboard**

### Sleep behavior right now

- **Sablier-managed**: `anythingllm`, `bentopdf`, `cbeaver`, `home`, `immich-power-tools`, `ittools`, `keep`, `omni-tools`, `paperless`, `seerr`, `speedtest-tracker`, `vert`, `whoami`
- **Always on / not wired to Sablier middleware**: `traefik`, `sablier`, `rustfs`, `adguard`, `netalertx`, `dockhand`, `immich`, `home-assistant`, `jellyfin`, `torrent`, `sonarr`, `radarr`, `prowlarr`, `bazarr`
- **Important exception**: `listmonk` still has `sablier.*` labels, but `config/traefik/dyn/listmonk.yml` does **not** attach a Sablier middleware. Treat it as not sleeping on request in the current repo.

---

## Current Service Groups

### Foundation

- **Traefik**
- **Sablier**
- **RustFS**
- **AdGuard Home**
- **NetAlertX**
- **whoami**

### Utilities and dashboards

- **Homepage**
- **AnythingLLM**
- **IT Tools**
- **CloudBeaver**
- **BentoPDF**
- **Omni Tools**
- **VERT**
- **Speedtest Tracker**

### App stacks

- **Karakeep** + `chrome` + `meilisearch`
- **Listmonk** + `listmonk-postgres` + optional `cftunnel`
- **Immich** + `immich-postgres` + `redis` + workers
- **Paperless-ngx** + PostgreSQL + Redis + Gotenberg + Tika
- **Media**: `jellyfin`, `seerr`, `immich-power-tools`, `torrent`, `sonarr`, `radarr`, `prowlarr`, `bazarr`
- **Home Assistant**

---

## Current Caveats

### 1. Local HTTPS uses mkcert

Local development uses `config/traefik/traefik.yml` with HTTPS on `websecure`.
Run `setup-dev.sh` to create the mkcert-backed files for
`https://*.localhost.me`, then start the stack with:

```bash
docker compose --profile all up --wait
```

For production ACME certificates, set:

- start with `docker compose -f docker-compose.prod.yml --profile all up -d`
- `DOMAIN`
- `ACME_EMAIL`
- `CF_DNS_API_TOKEN`

### 2. The media stack still depends on Gluetun

`services/media.yml` runs **Gluetun** as the shared network namespace for:

- `torrent`
- `sonarr`
- `radarr`

`prowlarr` and `bazarr` route directly on `traefik_public`.

The active compose config requires `OPENVPN_USER` and `OPENVPN_PASSWORD` for Gluetun. `setup-dev.sh` supplies local dummy values so config rendering works, but real media downloads need real VPN credentials.

### 3. There are parked service definitions

These files exist but are **not** included from `docker-compose.yml`:

- `services/hermes.yml`
- `services/teable.yml`
- `services/teable-migrate.yml`

---

## Read The Right Doc

- [Docs index](docs/index.md)
- [Architecture](docs/architecture.md)
- [Service reference](docs/services.md)
- [Customization](docs/customization.md)
- [Deploy through Dockhand](docs/dockhand.md)
- [Troubleshooting](docs/troubleshooting.md)
- [Queue-driven sleep status](docs/queue-driven-sleep.md)

---

## License

MIT. See [LICENSE](LICENSE).
