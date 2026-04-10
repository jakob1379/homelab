# Troubleshooting

Use this page when a service does not start, does not wake, or does not resolve. Start with [Architecture](architecture.md) to understand the request path, then match the symptom below. For the deployment flow, read [Deployment](portainer.md).

## Try It Now

Run these two checks before you dig into a specific failure:

```bash title="Check the current container state"
# 1. Check the bootstrap or full-stack containers
$ docker compose -f docker-compose.pods.yml ps
NAME                    IMAGE                          STATUS
homelab-pods-portainer-1     portainer/portainer-ce:2.25.1 Up
homelab-pods-dockhand-1      fnsys/dockhand:latest         Up
```

```bash title="Check whether Portainer is still in bootstrap mode"
# 2. Check whether you are still on bootstrap or already on routed traffic
$ curl -sk https://localhost:9443/api/status | jq '.Version'
"2.25.1"
```

If the direct `9443` endpoint works but `https://pods.${DOMAIN}` does not, you are still in bootstrap mode. That is expected until Portainer deploys the full stack.

## The "Starting..." Screen That Never Ends

**What you see:** You visit your app and get a loading page that says "Starting..." forever, then a "Bad Gateway" error or a browser error page.

**What's happening:** Traefik cannot reach the app because the container is stopped, unhealthy, or not on the right network.

```bash title="Debug a stuck wake-up flow"
# 1. Check if service is running
$ docker compose ps | grep immich
homelab-immich-server-1   ghcr.io/immich-app/immich-server:release   Up 2 hours (healthy)

# 2. Check service logs
$ docker compose logs immich-server
immich-server  | [Nest] 1  - 02/19/2026, 10:00:00 AM     LOG [NestFactory] Starting Nest application...
immich-server  | [Nest] 1  - 02/19/2026, 10:00:01 AM     LOG [InstanceLoader] DatabaseModule dependencies initialized

# 3. Common: Missing environment file
$ ls services/.env-immich
ls: cannot access 'services/.env-immich': No such file or directory

# 4. Common: Network not connected
$ docker network ls | grep traefik_public
NETWORK ID     NAME              DRIVER    SCOPE
abc123def456   traefik_public    bridge    local
```

## Certificate Warning

**Symptom:** Chrome/Firefox warns about self-signed certificate.

**Fix:** This is expected in development mode with `traefik.me`:
- Click "Advanced" → "Proceed anyway" (Chrome)
- Or add `-k` flag to curl: `curl -k https://...`

For production, ensure the Cloudflare token is valid and NetBird DNS points clients to AdGuard wildcard records that resolve hostnames to your server VPN IP. See [Deployment](portainer.md).

## Sablier "Starting..." Forever

**Symptom:** Service never becomes ready.

```bash title="Inspect Sablier and app readiness"
# Check Sablier logs
$ docker compose logs sablier
sablier  | INFO[0001] Successfully registered provider: Docker
sablier  | INFO[0001] Sablier started on :10000

# Check if service has healthcheck issues
$ docker compose ps karakeep
NAME                    IMAGE                        STATUS
homelab-karakeep-1      karakeep/karakeep:latest     Up 5 seconds (health: starting)

$ docker compose logs karakeep
karakeep  | Failed to connect to database: connection refused

# Force restart
$ docker compose restart karakeep
[+] Restarting 1/1
 ✔ Container homelab-karakeep-1  Started

# Check if replicas are stuck at 0 - start manually
$ docker compose up -d karakeep
[+] Running 1/1
 ✔ Container homelab-karakeep-1  Started
```

## Port Conflicts (53 for AdGuard)

**Symptom:** `Bind for 0.0.0.0:53 failed: port is already allocated`

**Fix:**
```bash title="Resolve an AdGuard port binding conflict"
# Default dev setup uses ADGUARD_DNS_PORT=1053 to avoid this.
# If you explicitly set ADGUARD_DNS_PORT=53, check conflicts with:
# Find what's using port 53
$ sudo lsof -i :53
COMMAND  PID   USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
systemd- 123   root   12u  IPv4  12345      0t0  UDP localhost:53

# On Ubuntu/Debian, disable systemd-resolved
$ sudo systemctl stop systemd-resolved
$ sudo systemctl disable systemd-resolved

# Or keep AdGuard on a non-conflicting host port
$ echo "ADGUARD_DNS_PORT=1053" >> .env
```

## Can't Access Services

**Symptom:** `whoami.traefik.me` doesn't resolve or connection refused.

**Checklist:**
```bash title="Check routing, DNS, and Traefik state"
# 1. Is Traefik running?
$ docker compose ps traefik
NAME                IMAGE                STATUS
homelab-traefik-1   traefik:3.6.9        Up 3 hours (healthy)

# 2. Check if DNS resolves (traefik.me should resolve to 127.0.0.1)
$ nslookup whoami.traefik.me
Server:  127.0.0.53
Address: 127.0.0.53#53

Name: whoami.traefik.me
Address: 127.0.0.1

# 3. Check Traefik logs for config errors
$ docker compose logs traefik | grep error
traefik  | ERROR: Failed to retrieve ACME certificate: rate limit exceeded

# 4. Verify Docker network exists
$ docker network ls | grep traefik_public
NETWORK ID     NAME              DRIVER    SCOPE
abc123def456   traefik_public    bridge    local

# 5. Check dynamic config is loaded
$ curl -k https://traefik.traefik.me/api/rawdata 2>/dev/null | jq '.routers | keys'
[
  "immich@file",
  "portainer@file",
  "traefik@file"
]
```

## Database Connection Refused

**Symptom:** One app starts, but logs show database connection errors.

```bash title="Inspect app-local database connectivity"
# Check app-local database containers
$ docker compose ps immich-postgres listmonk-postgres paperless-postgres
NAME                         IMAGE                    STATUS
homelab-immich-postgres-1    pgvector/pgvector:pg17  Up 20 minutes (healthy)
homelab-listmonk-postgres-1  postgres:17-alpine      Up 20 minutes (healthy)
homelab-paperless-postgres-1 postgres:17-alpine      Up 20 minutes (healthy)

# Check the failing app logs
$ docker compose logs immich-server --tail 30
immich-server  | [Nest] ... LOG [DatabaseRepository] Connected to database

# Check the matching DB logs
$ docker compose logs immich-postgres --tail 30
immich-postgres  | LOG:  database system is ready to accept connections

# Verify each app points to its own DB host
$ docker compose config | grep -E "DB_HOSTNAME|PAPERLESS_DBHOST|LISTMONK_db__host"
      DB_HOSTNAME: immich-postgres
      PAPERLESS_DBHOST: paperless-postgres
      LISTMONK_db__host: listmonk-postgres
```

If one database is unhealthy, restart only that app stack:

```bash title="Restart only the affected Immich stack"
$ docker compose up -d immich-postgres immich-server immich-microservices
```

## Media Requests Stuck or Never Download

**Symptom:** You request a movie/show in `requests.${DOMAIN}` but nothing starts downloading.

```bash title="Check media automation prerequisites"
# 1. Check VPN tunnel status
$ docker compose logs gluetun --tail 50
gluetun  | ERROR VPN settings: OPENVPN_USER is not set

# 2. Confirm VPN credentials are set
$ grep -E '^OPENVPN_USER=|^OPENVPN_PASSWORD=' .env
OPENVPN_USER=your_proton_openvpn_username
OPENVPN_PASSWORD=your_proton_openvpn_password

# 3. Check downloader + Arr services
$ docker compose ps gluetun qbittorrent sonarr radarr
NAME                    IMAGE                               STATUS
homelab-gluetun-1       qmcgaw/gluetun:latest              Up (healthy)
homelab-qbittorrent-1   lscr.io/linuxserver/qbittorrent    Up
homelab-sonarr-1        lscr.io/linuxserver/sonarr         Up
homelab-radarr-1        lscr.io/linuxserver/radarr         Up
```

If credentials were missing, set them in `.env` and restart media automation:

```bash title="Restart the media automation stack"
$ docker compose up -d gluetun qbittorrent sonarr radarr
```

## Home Assistant Network Issues

**Symptom:** Home Assistant can't connect to `traefik_public`.

**Fix:**
```bash title="Repair the Home Assistant shared network"
# Create the network if it doesn't exist
$ docker network create traefik_public
traefik_public

# In home-assistant/docker-compose.yml, the network is marked external: true
# So you must let the main stack create the network first
$ docker compose --profile infra up -d
[+] Running 6/6
 ✔ Container homelab-traefik-1   Started
 ✔ Container homelab-sablier-1   Started
 ...

# If you deploy through Portainer, let Portainer deploy the full
# stack before starting Home Assistant.

# Then start Home Assistant
$ cd home-assistant
$ docker compose --profile service up -d
[+] Running 1/1
 ✔ Container homeassistant  Started
```
