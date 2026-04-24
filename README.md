# Homelab

[![CI](https://github.com/jakob1379/homelab/actions/workflows/test-docker-compose.yml/badge.svg)](https://github.com/jakob1379/homelab/actions/workflows/test-docker-compose.yml)
[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-Ready-2496ED?logo=docker&logoColor=white)](https://docs.docker.com/compose/)
[![Traefik](https://img.shields.io/badge/Traefik-Proxy-24A1C1?logo=traefikproxy&logoColor=white)](https://traefik.io/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> **Docker Compose homelab with two entrypoints.** `docker-compose.yml` runs the main stack. `docker-compose.pods.yml` boots **Dockhand** as the separate control plane.

This repo is not zero-config anymore. The **Dockhand** bootstrap path is easy. The full **Traefik** stack still expects `ACME_EMAIL` and `CF_DNS_API_TOKEN` because `config/traefik/traefik.yml` is wired for **Cloudflare DNS-01** from the start.

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
[INFO] setup-dev.sh leaves password-style credentials alone, only generates app keys, and leaves optional service env overrides optional
[INFO] Generated development key: NEXTAUTH_SECRET
[INFO] Generated development key: MEILI_MASTER_KEY
[WARN] Missing required variables for docker compose --profile all:
 - ACME_EMAIL
 - CF_DNS_API_TOKEN
 - OPENVPN_USER
 - OPENVPN_PASSWORD
 ...
[INFO] Setup complete!
```

Fill the values you actually need, then start the profiles you want.

```bash title="Start infra first, then add apps"
# 2. Add the required values to .env
$ cat >> .env <<'EOF'
ACME_EMAIL=you@example.com
CF_DNS_API_TOKEN=your_cloudflare_token
EOF

# 3. Start the always-on foundation
$ docker compose --profile infra up -d
[+] Running ...
 ✔ Container homelab-traefik-1   Started
 ✔ Container homelab-sablier-1   Started
 ✔ Container homelab-rustfs-1    Started

# 4. Start a couple of apps
$ docker compose --profile apps up -d home keep
[+] Running ...
 ✔ Container homelab-home-1      Started
 ✔ Container homelab-keep-1      Started

# 5. Verify a routed endpoint
$ curl -k https://whoami.traefik.me
Hostname: homelab-whoami-1
IP: 172.20.0.2
```

!!! note
    `traefik.me` is still the local default domain. It resolves to `127.0.0.1`, so local routing works once the main stack is up.

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
- **VERT**
- **whoami**

### Direct Docker-label routes

These are currently routed with service labels instead of `config/traefik/dyn/*.yml`:

- **AdGuard**
- **Dockhand**
- **Home Assistant**
- **Immich**
- **Prowlarr**
- **Radarr**
- **Sonarr**
- **Speedtest Tracker**
- **torrent** (`https://torrent.${DOMAIN}`)
- **Traefik dashboard**

### Sleep behavior right now

- **Sablier-managed**: `anythingllm`, `bentopdf`, `cbeaver`, `home`, `immich-power-tools`, `ittools`, `jellyfin`, `keep`, `omni-tools`, `paperless`, `seerr`, `vert`, `whoami`
- **Always on / not wired to Sablier middleware**: `traefik`, `sablier`, `rustfs`, `adguard`, `netalertx`, `dockhand`, `immich`, `speedtest-tracker`, `home-assistant`, `torrent`, `sonarr`, `radarr`, `prowlarr`
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
- **Media**: `jellyfin`, `seerr`, `immich-power-tools`, `torrent`, `sonarr`, `radarr`, `prowlarr`
- **Home Assistant**

---

## Current Caveats

### 1. The main stack still expects Cloudflare values

Even in local development, `traefik` requires:

- `ACME_EMAIL`
- `CF_DNS_API_TOKEN`

That is not optional in the current compose setup.

### 2. The media stack is mid-transition

`services/media.yml` still contains the old commented **Gluetun** section, but the active stack now routes:

- `torrent`
- `sonarr`
- `radarr`
- `prowlarr`

directly on `traefik_public`.

`setup-dev.sh` still reports `OPENVPN_USER` and `OPENVPN_PASSWORD` as required for `--profile all`. That warning matches the repo's current bootstrap script, not the active Gluetun wiring.

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
