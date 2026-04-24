# Troubleshooting

Use this page when the current repo shape gets in your way: missing main-stack variables, bootstrap vs routed Dockhand confusion, stuck Sablier routes, or media-stack drift.

Read [Architecture](architecture.md) first if you do not know which stack you are actually debugging.

---

## Try It Now

```bash title="Check the bootstrap and main stacks first"
# 1. Pods stack
$ docker compose -f docker-compose.pods.yml ps
NAME                    IMAGE                  STATUS
homelab-pods-dockhand-1 fnsys/dockhand:v1.0.26 Up

# 2. Main stack foundation
$ docker compose ps traefik sablier whoami
NAME                IMAGE                   STATUS
homelab-traefik-1   traefik:3.6.9           Up (healthy)
homelab-sablier-1   sablierapp/sablier:1.8.1 Up
homelab-whoami-1    traefik/whoami:v1.10.4  Up
```

Those two commands tell you whether you are debugging:

- only the bootstrap control plane
- only the main stack
- or both

---

## Dockhand Works On `:3000` But Not On `docker.${DOMAIN}`

This is the normal bootstrap state.

```bash title="Check whether you are still in bootstrap mode"
$ curl -I http://localhost:3000
HTTP/1.1 200 OK
```

If that works but `https://docker.${DOMAIN}` does not, the main **Traefik** stack is not up yet.

Fix:

1. deploy the main stack
2. verify `traefik` is healthy
3. verify both stacks share `traefik_public`

---

## `docker compose --profile all config` Fails Immediately

The usual reason is missing required variables.

```bash title="Render the main stack and read the first failure"
$ docker compose --profile all config
required variable CF_DNS_API_TOKEN is missing a value: Set CF_DNS_API_TOKEN in .env, direnv, or Dockhand
```

The current repo expects at least these for the main ingress path:

- `ACME_EMAIL`
- `CF_DNS_API_TOKEN`

and app secrets for the services you include.

If you only want the control plane, use `docker-compose.pods.yml` instead of fighting the full stack.

---

## Sablier Shows "Starting..." Forever

This means one of three things:

1. the container is crashing
2. the route points at the wrong internal port
3. the Sablier group name does not match between the service and the middleware

```bash title="Inspect a stuck Sablier-managed route"
# 1. Check Sablier itself
$ docker compose logs sablier --tail 20
INFO[0001] Successfully registered provider: Docker

# 2. Check the target service
$ docker compose ps keep
NAME              IMAGE                               STATUS
homelab-keep-1    ghcr.io/karakeep-app/karakeep:...  Up

# 3. Check the target logs
$ docker compose logs keep --tail 50
...
```

Then compare:

- `sablier.group=keep` in `services/karakeep.yml`
- `group: keep` in `config/traefik/dyn/keep.yml`

If those do not match, the wake flow is broken.

---

## 502 / Bad Gateway

The issue is usually network attachment or a wrong port.

```bash title="Check network attachment and route target"
# 1. Verify traefik_public exists
$ docker network ls
NETWORK ID     NAME            DRIVER    SCOPE
...            traefik_public  bridge    local

# 2. Check the service is attached to traefik_public
$ docker compose ps immich-server
NAME                    IMAGE                               STATUS
homelab-immich-server-1 ghcr.io/immich-app/immich-server... Up (healthy)

# 3. Check the service logs
$ docker compose logs immich-server --tail 30
...
```

If the app is supposed to be routed by **Traefik**, it usually needs `traefik_public`.

Missing that network is the common failure mode.

---

## AdGuard Cannot Bind Port 53

The default dev port is `1053`. If you changed it to `53`, you may be fighting the host resolver.

```bash title="Check port 53 conflicts"
$ sudo lsof -i :53
COMMAND   PID USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
systemd   123 root   12u  IPv4  12345      0t0  UDP localhost:53
```

Fix one of these ways:

- keep `ADGUARD_DNS_PORT=1053`
- or stop the host resolver that already owns port `53`

```bash title="Keep the non-conflicting dev port"
$ printf '%s\n' 'ADGUARD_DNS_PORT=1053' >> .env
```

---

## Local Browser Shows A Certificate Warning

That is expected when you run the local `traefik.me` path without a trusted local CA.

```bash title="Use curl with the insecure flag in local dev"
$ curl -k https://whoami.traefik.me
Hostname: homelab-whoami-1
```

If this is production and you still get a bad cert, check:

1. `CF_DNS_API_TOKEN`
2. `ACME_EMAIL`
3. DNS resolution to the correct host
4. `docker compose logs traefik --tail 100`

---

## Home Assistant Cannot Reach The Shared Network

Bring up the foundation first so `traefik_public` exists, then start `ha`.

```bash title="Repair Home Assistant startup ordering"
# 1. Let the main stack create traefik_public
$ docker compose --profile infra up -d
[+] Running ...
 ✔ Container homelab-traefik-1  Started

# 2. Start Home Assistant with its narrow profile
$ docker compose --profile service up -d ha
[+] Running 1/1
 ✔ Container homelab-ha-1  Started
```

---

## Media Stack Does Not Match Older Docs Or Muscle Memory

Yes. The current repo changed here.

Current facts:

- the active qBittorrent service name is `torrent`
- `gluetun` is active for `torrent`, `sonarr`, and `radarr`
- `gluetun` carries `torrent`, `sonarr`, and `radarr` aliases on `media`
- `prowlarr` has no profile
- **Seerr** is still routed through a file-provider **Sablier** route
- `setup-dev.sh` requires `OPENVPN_USER` and `OPENVPN_PASSWORD`

Use commands that match the current service names.

```bash title="Check the current media services"
$ docker compose ps gluetun torrent sonarr radarr prowlarr seerr jellyfin
NAME                IMAGE                                 STATUS
homelab-gluetun-1   qmcgaw/gluetun:...                    Up
homelab-torrent-1   lscr.io/linuxserver/qbittorrent:...  Up
homelab-sonarr-1    lscr.io/linuxserver/sonarr:...       Up
homelab-radarr-1    lscr.io/linuxserver/radarr:...       Up
homelab-prowlarr-1  lscr.io/linuxserver/prowlarr:...     Up
homelab-seerr-1     ghcr.io/seerr-team/seerr:...         Up
homelab-jellyfin-1  linuxserver/jellyfin:...             Up
```

If `torrent`, `sonarr`, or `radarr` cannot reach the network, debug `gluetun` first.
