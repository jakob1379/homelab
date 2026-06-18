---
title: Architecture
---

# Architecture

This page explains how the repo is wired now: entrypoints, profiles, routing sources, networks, and current exceptions. If you need the concrete service list, read [Service Reference](services.md). If you want to add a service, read [Configuration](customization.md).

---

## Try It Now

```bash title="Bring up the bootstrap and foundation layers"
# 1. Start the separate Dockhand stack
$ docker compose -f docker-compose.pods.yml up -d
[+] Running 1/1
 ✔ Container homelab-pods-dockhand-1  Started

# 2. Start the always-on foundation
$ docker compose --profile infra up -d
[+] Running ...
 ✔ Container homelab-traefik-1   Started
 ✔ Container homelab-sablier-1   Started
 ✔ Container homelab-rustfs-1    Started

# 3. Inspect live routers
$ curl -s https://traefik.localhost.me/api/http/routers | jq -r '.[].name'
api@docker
dockhand@docker
whoami@file
home@file
...
```

That output tells you two things immediately:

1. this repo uses both the **Docker** and **file** providers in **Traefik**
2. **Dockhand** lives in the separate pods stack but is still discovered once **Traefik** is up

---

## The Two Compose Entrypoints

### Main stack: `docker-compose.yml`

This is the runtime stack. It includes the active definitions under `services/` plus `home-assistant/docker-compose.yml`.

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
  - services/dumbassets.yml
  - services/media.yml
  - services/hermes.yml
  - services/homepage.yml
  - home-assistant/docker-compose.yml
```

### Bootstrap stack: `docker-compose.pods.yml`

This is intentionally small.

```yaml title="docker-compose.pods.yml"
include:
  - services/pods.yml
```

`services/pods.yml` defines only **Dockhand**.

---

## Profiles That Actually Exist

| Profile | Used for |
|---|---|
| `dev` | Full main stack with local mkcert-backed Traefik HTTPS |
| `prod` | Full main stack with Cloudflare DNS-01 ACME Traefik HTTPS |
| `infra` | **Traefik**, **Sablier**, **RustFS**, **AdGuard**, **NetAlertX**, **whoami** |
| `apps` | Most application services |
| `tunnel` | `cftunnel` in `services/listmonk.yml` |
| `service` | Narrow profile currently used by **Home Assistant** |

```bash title="Start only Home Assistant with its narrow profile"
$ docker compose --profile service up -d ha
[+] Running 1/1
 ✔ Container homelab-ha-1  Started
```

!!! note
    `ha` is also in `profiles: [apps, service, dev, prod]`, so `docker compose --profile apps up -d ha` still works. `service` is just the narrower switch.

### Important profile footgun

Use exactly one full-stack profile at a time: `dev` or `prod`. `dev` starts the mkcert-backed `traefik-dev` service, while `prod` starts the stable public `traefik` service with the production override block for Cloudflare DNS-01 ACME.

`prowlarr` in `services/media.yml` currently has **no profile**. In Compose, that means it is part of the default service set for the main stack.

Treat that as current behavior, not a clean design choice.

---

## Routing Model

This repo uses both **Traefik** providers.

| Source | Lives in | Used for |
|---|---|---|
| **Docker provider** | service labels | simple direct routes and always-on services |
| **File provider** | `config/traefik/dyn/*.yml` | explicit routers, middleware chains, and most **Sablier** routes |

### File-provider route example

`config/traefik/dyn/keep.yml` is a normal pattern in this repo.

```yaml title="config/traefik/dyn/keep.yml"
http:
  routers:
    keep:
      rule: Host(`keep.{{ env "DOMAIN" }}`)
      entrypoints: [websecure]
      service: keep
      middlewares: [sablier-keep@file, startup-retry@file]
```

That route lives in the file provider because it needs both:

- a **Sablier** middleware
- the shared `startup-retry@file` middleware from `config/traefik/dyn/common.yml`

### Docker-label route example

`services/immich.yml` is the direct-label pattern.

```yaml title="services/immich.yml"
labels:
  - traefik.enable=true
  - traefik.docker.network=traefik_public
  - traefik.http.routers.immich.rule=Host(`photos.${DOMAIN:-localhost.me}`)
  - traefik.http.routers.immich.entrypoints=websecure
  - traefik.http.services.immich.loadbalancer.server.port=2283
```

That is the simpler option when you do not need a file-provider middleware chain.

### What is currently in each bucket

#### File-provider routes

- `anythingllm.yml`
- `bentopdf.yml`
- `cbeaver.yml`
- `dumbassets.yml`
- `ha.yml`
- `home.yml`
- `immich-power-tools.yml`
- `ittools.yml`
- `keep.yml`
- `listmonk.yml`
- `netalertx.yml`
- `omni-tools.yml`
- `paperless.yml`
- `rustfs.yml`
- `seerr.yml`
- `speedtest-tracker.yml`
- `vert.yml`
- `whoami.yml`

#### Direct Docker-label routes

- `traefik` dashboard from `services/networking.yml`
- `adguard` from `services/networking.yml`
- `dockhand` from `services/pods.yml`
- `hermes` from `services/hermes.yml`
- `immich` from `services/immich.yml`
- `jellyfin`, `torrent`, `sonarr`, `radarr`, `prowlarr`, `bazarr` from `services/media.yml`

---

## Sleep Model

This repo does **not** put every routed app behind **Sablier**.

### Currently Sablier-managed

| Service | Middleware file | Idle timeout |
|---|---|---|
| `whoami` | `common.yml` (`sablier-default`) | `10m` |
| `keep` | `keep.yml` | `15m` |
| `paperless` | `paperless.yml` | `15m` |
| `speedtest-tracker` | `speedtest-tracker.yml` | `15m` |
| `anythingllm` | `anythingllm.yml` | `30m` |
| `bentopdf` | `bentopdf.yml` | `30m` |
| `cbeaver` | `cbeaver.yml` | `30m` |
| `dumbassets` | `dumbassets.yml` | `30m` |
| `home` | `home.yml` | `30m` |
| `immich-power-tools` | `immich-power-tools.yml` | `30m` |
| `ittools` | `ittools.yml` | `30m` |
| `omni-tools` | `omni-tools.yml` | `30m` |
| `seerr` | `seerr.yml` | `30m` |
| `vert` | `vert.yml` | `30m` |

### Currently not behind a Sablier middleware

- **Traefik**
- **Sablier**
- **RustFS**
- **AdGuard**
- **NetAlertX**
- **Dockhand**
- **Immich**
- **Home Assistant**
- **Hermes**
- **Jellyfin**
- **torrent**
- **Sonarr**
- **Radarr**
- **Prowlarr**
- **Bazarr**
- **Listmonk**

### Current exception: Listmonk

`services/listmonk.yml` still sets:

```yaml
labels:
  - sablier.enable=true
  - sablier.group=listmonk
```

but `config/traefik/dyn/listmonk.yml` does not attach a Sablier middleware. That means the route is not currently using sleep-on-request behavior.

---

## Networks

| Network | Purpose | Current users |
|---|---|---|
| `traefik_public` | shared ingress network | normal Docker-network routed services; host-networked routes use `host.docker.internal` |
| `keep` | **Karakeep** internals | `keep`, `chrome`, `meilisearch` |
| `immich` | **Immich** internals | `immich-*`, `redis`, `immich-power-tools` |
| `paperless` | **Paperless** internals | `paperless-*` |
| `listmonk` | **Listmonk** isolation | `listmonk`, `listmonk-postgres`, optional `cftunnel` |
| `media` | media apps | `jellyfin`, `seerr`, `gluetun` with `torrent`/`sonarr`/`radarr`/`flaresolverr`/`byparr` sharing its namespace, `prowlarr`, `bazarr` |

### Current media-stack reality

`services/media.yml` runs **Gluetun** for the download-automation path.

That means:

- `gluetun` is attached to `media` and `traefik_public`
- `torrent`, `sonarr`, `radarr`, `flaresolverr`, and `byparr` share the `gluetun` network namespace
- `gluetun` carries `torrent`, `sonarr`, `radarr`, `flaresolverr`, and `byparr` aliases on `media` so existing service names still resolve internally
- external Docker-label routes on `gluetun` are only `torrent`, `sonarr`, and `radarr`; `flaresolverr` and `byparr` are internal only
- `prowlarr` remains directly attached to `media` and `traefik_public`
- `bazarr` remains directly attached to `media` and `traefik_public`

---

## Hermes Placement

**Hermes** runs as one always-on container with the built-in dashboard enabled. It is not behind **Sablier** because the Slack Socket Mode gateway needs to stay connected.

Traefik reaches the dashboard through Docker labels on `services/hermes.yml`. The Docker provider infers the `hermes.{{ env "DOMAIN" }}` host rule from the Compose service name; the labels only enable Traefik, select `websecure`, attach `netbird-users-only@file` and `startup-retry@file`, and set the dashboard port to `9119`. Dashboard access is limited to NetBird/VPN source ranges before Hermes' own dashboard authentication runs.

That network boundary does not protect Slack. Slack access must stay constrained with Hermes' Slack configuration, especially `SLACK_ALLOWED_USERS` and `SLACK_ALLOWED_CHANNELS` in the `ops` profile's `.env`.

Hermes profiles isolate config, secrets, memory, sessions, skills, cron jobs, and gateway state. They do not sandbox CPU, memory, network access, or filesystem access granted to the container. Do not mount `/var/run/docker.sock` into Hermes unless host-level Docker control is intentional.

---

## Home Assistant Placement

**Home Assistant** lives under `home-assistant/`, but the service is included from the root `docker-compose.yml`.

```text title="Home Assistant location"
home-assistant/
├── docker-compose.yml
└── configuration.yaml
```

The service runs in `network_mode: host` for LAN discovery, and **Traefik** reaches it through `config/traefik/dyn/ha.yml` at `http://host.docker.internal:8123/`.

---

## Parked Definitions

These files exist under `services/` but are not included from `docker-compose.yml`:

- `services/teable.yml`
- `services/teable-migrate.yml`

Do not document them as part of the active stack unless they are added to the root include list.
