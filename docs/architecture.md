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
$ curl -sk https://traefik.traefik.me/api/http/routers | jq -r '.[].name'
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
  - services/media.yml
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
| `infra` | **Traefik**, **Sablier**, **RustFS**, **AdGuard**, **NetAlertX**, **whoami** |
| `apps` | Most application services |
| `all` | Convenience profile for the full main stack |
| `tunnel` | `cftunnel` in `services/listmonk.yml` |
| `service` | Narrow profile currently used by **Home Assistant** |

```bash title="Start only Home Assistant with its narrow profile"
$ docker compose --profile service up -d ha
[+] Running 1/1
 ✔ Container homelab-ha-1  Started
```

!!! note
    `ha` is also in `profiles: [apps, all, service]`, so `docker compose --profile apps up -d ha` still works. `service` is just the narrower switch.

### Important profile footgun

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
  - traefik.http.routers.immich.rule=Host(`photos.${DOMAIN:-traefik.me}`)
  - traefik.http.routers.immich.entrypoints=websecure
  - traefik.http.services.immich.loadbalancer.server.port=2283
```

That is the simpler option when you do not need a file-provider middleware chain.

### What is currently in each bucket

#### File-provider routes

- `anythingllm.yml`
- `bentopdf.yml`
- `cbeaver.yml`
- `home.yml`
- `immich-power-tools.yml`
- `ittools.yml`
- `jellyfin.yml`
- `keep.yml`
- `listmonk.yml`
- `netalertx.yml`
- `omni-tools.yml`
- `paperless.yml`
- `rustfs.yml`
- `seerr.yml`
- `vert.yml`
- `whoami.yml`

#### Direct Docker-label routes

- `traefik` dashboard from `services/networking.yml`
- `adguard` from `services/networking.yml`
- `dockhand` from `services/pods.yml`
- `immich` from `services/immich.yml`
- `speedtest-tracker` from `services/speedtest-tracker.yml`
- `ha` from `home-assistant/docker-compose.yml`
- `torrent`, `sonarr`, `radarr`, `prowlarr` from `services/media.yml`

---

## Sleep Model

This repo does **not** put every routed app behind **Sablier**.

### Currently Sablier-managed

| Service | Middleware file | Idle timeout |
|---|---|---|
| `whoami` | `common.yml` (`sablier-default`) | `10m` |
| `keep` | `keep.yml` | `15m` |
| `paperless` | `paperless.yml` | `15m` |
| `anythingllm` | `anythingllm.yml` | `30m` |
| `bentopdf` | `bentopdf.yml` | `30m` |
| `cbeaver` | `cbeaver.yml` | `30m` |
| `home` | `home.yml` | `30m` |
| `immich-power-tools` | `immich-power-tools.yml` | `30m` |
| `ittools` | `ittools.yml` | `30m` |
| `jellyfin` | `jellyfin.yml` | `30m` |
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
- **Speedtest Tracker**
- **Home Assistant**
- **torrent**
- **Sonarr**
- **Radarr**
- **Prowlarr**
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
| `traefik_public` | shared ingress network | all routed services |
| `keep` | **Karakeep** internals | `keep`, `chrome`, `meilisearch` |
| `immich` | **Immich** internals | `immich-*`, `redis`, `immich-power-tools` |
| `paperless` | **Paperless** internals | `paperless-*` |
| `listmonk` | **Listmonk** isolation | `listmonk`, `listmonk-postgres`, optional `cftunnel` |
| `media` | media apps | `jellyfin`, `seerr`, `gluetun`, `prowlarr` |

### Current media-stack reality

`services/media.yml` runs **Gluetun** for the download-automation path.

That means:

- `gluetun` is attached to `media` and `traefik_public`
- `torrent`, `sonarr`, and `radarr` share the `gluetun` network namespace
- `gluetun` carries `torrent`, `sonarr`, and `radarr` aliases on `media` so existing service names still resolve internally
- `prowlarr` remains directly attached to `media` and `traefik_public`

---

## Home Assistant Placement

**Home Assistant** lives under `home-assistant/`, but the service is included from the root `docker-compose.yml`.

```text title="Home Assistant location"
home-assistant/
├── docker-compose.yml
└── configuration.yaml
```

The service joins `traefik_public` and is routed by Docker labels, not a file-provider route.

---

## Parked Definitions

These files exist under `services/` but are not included from `docker-compose.yml`:

- `services/hermes.yml`
- `services/teable.yml`
- `services/teable-migrate.yml`

Do not document them as part of the active stack unless they are added to the root include list.
