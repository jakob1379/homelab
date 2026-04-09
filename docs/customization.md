---
title: Configuration
---

# Add a Custom Service

Use this page to add your own Docker services to the stack. The path is simple: define the container, add the router, include the file in `docker-compose.yml`, then verify it works. For the architecture behind the pattern, read [Architecture](architecture.md). For deployment, see [Deployment](portainer.md). For failures, use [Troubleshooting](troubleshooting.md).

---

## Try It Now

Add a custom service to your homelab:

```bash
# 1. Create the service definition
$ cat > services/custom.yml << 'EOF'
services:
  nginx-demo:
    profiles: [apps]
    image: nginx:alpine
    networks: [traefik_public]
    labels:
      - traefik.enable=true
      - sablier.enable=true
      - sablier.group=demo
EOF
```

The labels in step 1 only mark the service as Traefik/Sablier-managed. Sleep-on-request behavior is activated in step 2 by adding the Sablier middleware to the router.

```bash
# 2. Create the router config
$ cat > config/traefik/dyn/demo.yml << 'EOF'
http:
  routers:
    demo:
      rule: Host(`demo.{{ env "DOMAIN" }}`)
      entrypoints: [websecure]
      service: demo
      middlewares: [sablier-demo@file]
      tls:
        certResolver: cfresolver
  services:
    demo:
      loadBalancer:
        servers:
          - url: http://nginx-demo:80/
  middlewares:
    sablier-demo:
      plugin:
        sablier:
          group: demo
          sablierUrl: http://sablier:10000
          sessionDuration: 5m
EOF
```

```bash
# 3. Include in root compose
$ sed -i 's|include:|include:\n  - services/custom.yml          # Your custom services|' docker-compose.yml
```

```bash
# 4. Validate and deploy
$ docker compose config > /dev/null && echo "✓ Config valid"
✓ Config valid

$ docker compose up -d nginx-demo
[+] Running 1/1
 ✔ Container homelab-nginx-demo-1  Started

# 5. Test it
$ curl -k https://demo.traefik.me
<!DOCTYPE html>
<html>
<head><title>Welcome to nginx!</title></head>
...
```

✅ **Done!** Visit `https://demo.traefik.me` in your browser.

---

## Adding a New Service

Here's how to add any Docker-based app in four steps. We'll use a fictional app called "MyApp" as an example, but you can substitute any image you want.

### Step 1: Create the Service Definition

**Location:** `services/custom.yml`

This file defines your Docker container: what image to use, **environment variables**, volumes, and which network it joins.

```yaml
services:
  myapp:  # Service name (used in Traefik config and Docker commands)
    profiles: [apps]  # Groups services; 'apps' for applications
    image: myapp:latest  # Docker image to pull
    container_name: myapp  # Optional: friendly name for 'docker compose logs'
    networks:
      - traefik_public  # Required: joins the proxy network
    environment:
      - PUID=1000  # Common: map to your user ID
      - PGID=1000  # Common: map to your group ID
      - TZ=America/New_York  # Your timezone
    volumes:
      - ./data/myapp:/config  # Persist configuration
    labels:
      - traefik.enable=true  # Tells Traefik to route traffic here
      - sablier.enable=true  # Marks service as Sablier-managed
      - sablier.group=myapp  # Groups containers for Sablier
    restart: unless-stopped
```

**Key decisions to make:**

| Decision | What to choose | Example |
|----------|---------------|---------|
| Service name | Short, lowercase, no spaces | `jellyfin`, `vaultwarden` |
| Profile | `apps` for most services, `infra` for core infrastructure | `apps` |
| Network | Always `traefik_public` for proxied services | `traefik_public` |
| Volume paths | `./data/<service>` for local bind mounts | `./data/myapp:/config` |

!!! warning
    Forgetting `networks: [traefik_public]` is the #1 mistake when adding services. Without this network, **Traefik** cannot reach your container and you'll get a "Bad Gateway" error.

---

### Step 2: Create the Traefik Router Configuration

**Location:** `config/traefik/dyn/myapp.yml`

This file tells **Traefik** how to route traffic. If you're wondering "what's a reverse proxy?", think of it like a smart receptionist. When someone visits `myapp.yourdomain.com`, **Traefik** is the one who receives that request and forwards it to the right container.

```yaml
http:
  routers:
    myapp:  # Router name (unique, matches service name usually)
      rule: Host(`myapp.{{ env "DOMAIN" }}`)  # Domain matching rule
      entrypoints: [websecure]  # Listen on HTTPS (port 443)
      service: myapp  # Which service definition to use (below)
      middlewares: [sablier-myapp@file]  # Enable on-demand loading
      tls:
        certResolver: cfresolver  # Auto-generate SSL certificate

  services:
    myapp:  # Service name (referenced by router)
      loadBalancer:
        servers:
          - url: http://myapp:8080/  # Internal container address

  middlewares:
    sablier-myapp:  # Middleware name (matches reference above)
      plugin:
        sablier:
          group: myapp  # Must match sablier.group label in Step 1
          sablierUrl: http://sablier:10000  # Sablier API endpoint
          sessionDuration: 30m  # Keep running 30 min after last request
```

!!! warning
    The `group` name in `middlewares.sablier-myapp.plugin.sablier.group` **must** match the `sablier.group` label in your service definition. If they don't match, **Sablier** won't be able to start/stop your container.

---

### Step 3: Include in Root Compose File

**Location:** `docker-compose.yml` (root directory)

Add your service file to the includes list so Docker Compose knows to load it:

```yaml
include:
  - services/networking.yml      # Traefik, Sablier, AdGuard
  - services/portainer.yml       # Docker management
  - services/custom.yml          # Your custom services
```

---

### Step 4: Test and Deploy

Run these commands in order:

```bash
# 1. Validate configuration (catches syntax errors)
$ docker compose config > /dev/null && echo "✓ Config valid"
✓ Config valid
```

```bash
# 2. Pull the image
$ docker compose pull myapp
[+] Pulling 1/1
 ✔ myapp Pulled
```

```bash
# 3. Start the service
$ docker compose up -d myapp
[+] Running 2/2
 ✔ Container homelab-myapp-1  Started
```

```bash
# 4. Check logs for errors
$ docker compose logs myapp --tail 50
INFO:     Started server process [1]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
```

```bash
# 5. Verify it's running
$ docker compose ps myapp
NAME              IMAGE         STATUS
homelab-myapp-1   myapp:latest  Up 30 seconds
```

```bash
# 6. Test access (should see Sablier loading page or your app)
$ curl -k https://myapp.${DOMAIN:-traefik.me}
<!DOCTYPE html>
<html>
  <head><title>MyApp</title></head>
  <body>Welcome to MyApp</body>
</html>
```

---

## Understanding Service Labels

Labels are how containers send notes to **Traefik** and **Sablier**. You know how Docker containers are isolated by default? They can't see each other unless you connect them to the same network. Labels are like sticky notes you put on the container that say "hey **Traefik**, route traffic to me" or "hey **Sablier**, you can put me to sleep when I'm idle."

### What Each Label Does

```yaml
labels:
  # Required: Tells Traefik this container should receive traffic
  - traefik.enable=true

  # Optional: Marks service as Sablier-managed
  # (router must also reference a sablier middleware)
  - sablier.enable=true

  # Required for Sablier: Groups related containers
  # If your app has a database, it shares this group name
  - sablier.group=myapp
```

### Why Use `.Labels` Instead of Hardcoding?

You'll see this pattern in some **Traefik** configurations:

```yaml
# Using template syntax (dynamic)
rule: 'Host(`{{ index .Labels "com.docker.compose.service" }}.{{ env "DOMAIN" }}`)'

# vs hardcoding (static)
rule: 'Host(`myapp.{{ env "DOMAIN" }}`)'
```

**Use dynamic labels when:**

- You want reusable configuration files
- Multiple services share similar routing patterns
- You're using Docker Swarm or dynamic service discovery

**Use hardcoding when:**

- You want explicit, readable configuration
- You're managing a single homelab server
- Simplicity trumps reusability

This stack uses **hardcoded** values in router configs because they're easier to read and debug for individual services.

### How `${DOMAIN}` Works

There are two different mechanisms in this stack:

1. **Set your domain** in a `.env` file at the project root:
   ```bash
   $ echo "DOMAIN=example.com" > .env
   ```

2. **Docker Compose interpolation** (for Compose files):
   - `${DOMAIN}` and `${DOMAIN:-traefik.me}` are expanded by Compose before containers start.
   - Example: Homepage labels in `services/*.yml`.

3. **Traefik file-provider templates** (for `config/traefik/dyn/*.yml`):
   - Use Go templating with Sprig's `env` function.
   - Example: `rule: 'Host(`myapp.{{ env "DOMAIN" }}`)'`

4. **Fallbacks for local testing**:
   - In Compose files, `${DOMAIN:-traefik.me}` keeps local dev working even if `DOMAIN` is not set.

### Homepage Labels (Optional)

If you want services to appear on the **[Homepage](https://gethomepage.dev)** dashboard automatically, add these labels:

```yaml
labels:
  - traefik.enable=true
  - sablier.enable=true
  - sablier.group=myapp
  - homepage.group=Utilities          # Category examples: Developer, Utilities, Networking, Storage & Data, Communication, Smart Home, Media & Files
  - homepage.name=MyApp               # Display name on the dashboard
  - homepage.icon=myapp.png           # Icon file (see gethomepage.dev for available icons)
  - homepage.href=https://myapp.${DOMAIN:-traefik.me}
  - homepage.description=A brief description of what this does  # Shown on hover
```

Use `homepage.siteMonitor` and `homepage.statusStyle` only for always-on services. Do not set them on Sablier-managed services, or Homepage health checks can generate unnecessary traffic and log noise while those containers are sleeping.

Widget definitions can also live in labels:

```yaml
labels:
  - homepage.group=Developer
  - homepage.name=Traefik
  - homepage.icon=traefik.png
  - homepage.href=https://traefik.${DOMAIN:-traefik.me}
  - homepage.widget.type=traefik
  - homepage.widget.url=http://traefik:8080
```

For widgets that need authentication, keep credentials in environment variables and reference them in labels.

**Homepage** discovers these labels via Docker, so discovery itself does not wake services. Keep active health/status checks disabled on Sablier-managed services. Use practical groups so related services stay together:

- **Developer**: Admin and diagnostics tools like **Portainer**, **Dozzle**, **Traefik**, **Whoami**
- **Media & Files**: Photo, video, document, and content tools (**Immich**, **Jellyfin**, **Karakeep**, **Paperless**)
- **Utilities**: General utilities (**IT Tools**, **Omni Tools**, **BentoPDF**)
- **Networking**: DNS and network services (**AdGuard**, **NetAlertX**)
- **Storage & Data**: Storage and data interfaces (**RustFS**, **CloudBeaver**)
- **Communication**: Messaging and campaigns (**Listmonk**)
- **Smart Home**: Home automation services (**Home Assistant**)

!!! note
    **Homepage** discovers services via the Docker API, not through **Traefik**. This means it can display stopped services without waking them up.

---

## Common Patterns

### Pattern A: Simple Stateless Service

Services without databases or persistent storage (like a dashboard or simple web app):

```yaml
# services/custom.yml
services:
  homepage:
    profiles: [apps]
    image: ghcr.io/gethomepage/homepage:latest
    networks: [traefik_public]
    environment:
      - TZ=America/New_York
    volumes:
      - ../config/homepage:/app/config
    labels:
      - traefik.enable=true
      - sablier.enable=true
      - sablier.group=homepage
```

```yaml
# config/traefik/dyn/home.yml
http:
  routers:
    home:
      rule: Host(`home.{{ env "DOMAIN" }}`)
      entrypoints: [websecure]
      service: home
      middlewares: [sablier-home@file]
      tls:
        certResolver: cfresolver

  services:
    home:
      loadBalancer:
        servers:
          - url: http://home:3000/

  middlewares:
    sablier-home:
      plugin:
        sablier:
          group: home
          sablierUrl: http://sablier:10000
          sessionDuration: 30m
```

### Pattern B: Service with Database

Services that need a database get two entries in the same file:

```yaml
# services/custom.yml
services:
  myapp:  # The main application
    profiles: [apps]
    image: myapp:latest
    networks: [traefik_public]
    environment:
      - DATABASE_URL=mysql://myapp:secret@myapp-db:3306/myapp
      - TZ=America/New_York
    volumes:
      - ./data/myapp:/config
    labels:
      - traefik.enable=true
      - sablier.enable=true
      - sablier.group=myapp  # Same group as the database
    depends_on:
      - myapp-db

  myapp-db:  # The database
    profiles: [apps]
    image: mariadb:11
    networks: [traefik_public]
    environment:
      - MYSQL_DATABASE=myapp
      - MYSQL_USER=myapp
      - MYSQL_PASSWORD=secret
      - MYSQL_ROOT_PASSWORD=change_me
    volumes:
      - ./data/myapp-db:/var/lib/mysql
    # No traefik.enable label, since the database isn't accessed from outside
    # No sablier labels, so keep database always running
```

**Key differences for database-backed services:**

| Aspect | Application | Database |
|--------|-------------|----------|
| Traefik labels | Yes (`traefik.enable=true`) | No |
| Sablier labels | Yes | No |
| Sablier group | Yes (`sablier.group=myapp`) | N/A |
| Router config | Yes (`config/traefik/dyn/myapp.yml`) | No |

The router config only needs entries for the application, not the database.

---

## Troubleshooting

### "Service Unavailable" or 502 Error

**Check:** Container is running
```bash
$ docker compose ps myapp
NAME              IMAGE         STATUS
homelab-myapp-1   myapp:latest  Up 5 minutes

# If not running:
$ docker compose logs myapp --tail 50
```

**Check:** Container joined the network
```bash
$ docker network inspect traefik_public | grep myapp
# Should show both myapp and traefik containers
```

**Check:** Port matches
```bash
# In your container:
$ docker exec myapp netstat -tlnp
# Port here must match the URL in config/traefik/dyn/myapp.yml (for example `:8080`)
```

**If 502 only happens on the first request after wake-up:** Add a retry middleware and include it after your Sablier middleware.
```yaml
http:
  middlewares:
    startup-retry:
      retry:
        attempts: 30
        initialInterval: 1s

  routers:
    myapp:
      middlewares: [sablier-myapp@file, startup-retry@file]
```

### Sablier Shows "Starting..." Forever

**Check:** Sablier can see the container
```bash
$ docker compose logs sablier --tail 20
# Look for errors about group 'myapp'
```

**Check:** Labels match exactly
```bash
# These must match:
# 1. services/custom.yml: sablier.group=myapp
# 2. config/traefik/dyn/myapp.yml: middlewares.sablier-myapp.plugin.sablier.group=myapp
```

**Check:** Container actually starts
```bash
$ docker compose up myapp  # Run without -d to see real-time logs
# Look for crash loops or port conflicts
```

### SSL Certificate Errors

**Check:** Domain resolves correctly
```bash
$ nslookup myapp.${DOMAIN}
# Should return your server's IP
```

**Check:** Let's Encrypt isn't rate-limited
```bash
$ docker compose logs traefik --tail 100 | grep -i "rate\|error"
# Too many failed attempts = temporary ban (wait 1 hour)
```

### Changes Not Taking Effect

**Did you change static or dynamic config?**
```bash
# Dynamic files in config/traefik/dyn/ are hot-reloaded automatically.
# Restart Traefik only if you changed static config (config/traefik/traefik.yml).
$ docker compose restart traefik
```

**Is the config file valid YAML?**
```bash
$ docker compose config  # Validates all included files
✓ Config valid
```

**Did you reload Docker Compose?**
```bash
$ docker compose up -d  # Re-reads docker-compose.yml includes
```

---

## Quick Reference

| File | Purpose | Edit When |
|------|---------|-----------|
| `services/custom.yml` | Container definition | Adding/removing services |
| `config/traefik/dyn/*.yml` | Routing rules | Changing domains, ports, middleware |
| `docker-compose.yml` | Include list | Adding service files |
| `.env` | Environment variables | Changing domain, secrets |

| Label | Purpose | Required? |
|-------|---------|-----------|
| `traefik.enable=true` | Exposes service to proxy | Yes |
| `sablier.enable=true` | Marks service as Sablier-managed (requires router middleware) | No |
| `sablier.group=name` | Groups containers for start/stop | If using Sablier |

---

## Changing Domain

```bash
# Option 1: Set environment variable
$ export DOMAIN=mydomain.com
$ docker compose up -d

# Option 2: Edit .env file
$ echo "DOMAIN=mydomain.com" > .env
$ docker compose up -d
```

---

## Modifying Sablier Timeout

Edit `config/traefik/dyn/common.yml`:

```yaml
middlewares:
  sablier-default:
    plugin:
      sablier:
        sessionDuration: 60m  # Keep running for 60 minutes after last request
```

Changes in `dyn/` are hot-reloaded. Restart **Traefik** only if you changed static config:

```bash
$ docker compose restart traefik
```

---

## Excluding a Service from Sablier

Remove **Sablier** labels and middleware:

```yaml
services:
  portainer:
    labels:
      - traefik.enable=true
      # Remove these:
      # - sablier.enable=true
      # - sablier.group=portainer
```

And update the router:

```yaml
http:
  routers:
    portainer:
      # ...
      # middlewares: [sablier-portainer@file]  # Remove this
```

---

## Adding IP Restrictions

```yaml
# config/traefik/dyn/common.yml
http:
  middlewares:
    admin-only:
      ipAllowList:
        sourceRange:
          - 10.0.0.0/8
          - 172.16.0.0/12
          - 192.168.0.0/16
          - 100.64.0.0/10  # Tailscale/Netbird

# Apply to any router
http:
  routers:
    sensitive-app:
      # ...
      middlewares: [admin-only@file, sablier-app@file]
```

---

## Backup & Restore

### Backup Volumes

```bash
# Backup Immich database
$ docker run --rm -v homelab_immich_postgres_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/immich-postgres-backup.tar.gz -C /data .

# Backup Listmonk database
$ docker run --rm -v homelab_listmonk_postgres_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/listmonk-postgres-backup.tar.gz -C /data .

# Backup Paperless database
$ docker run --rm -v homelab_paperless_postgres_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/paperless-postgres-backup.tar.gz -C /data .

# Backup Karakeep
$ docker run --rm -v homelab_karakeep_data:/data -v $(pwd):/backup alpine \
  tar czf /backup/karakeep-backup.tar.gz -C /data .

# Backup all volumes
$ for vol in homelab_immich_postgres_data homelab_listmonk_postgres_data homelab_paperless_postgres_data homelab_karakeep_data homelab_meilisearch_data; do
  docker run --rm -v $vol:/data -v $(pwd):/backup alpine \
    tar czf /backup/$vol-$(date +%Y%m%d).tar.gz -C /data .
done
```

### Restore Volumes

```bash
# Restore Listmonk database (example)
$ docker run --rm -v homelab_listmonk_postgres_data:/data -v $(pwd):/backup alpine \
  sh -c "cd /data && tar xzf /backup/listmonk-postgres-backup.tar.gz"

# Restart services
$ docker compose restart listmonk-postgres listmonk
```

### Automated Backups with systemd Timer

Use a systemd timer instead of cron for predictable startup behavior, status visibility, and native logging.

Create backup script:

```bash
$ sudo tee /usr/local/bin/homelab-backup.sh > /dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="/backups/homelab-$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

for vol in homelab_immich_postgres_data homelab_listmonk_postgres_data homelab_paperless_postgres_data homelab_karakeep_data; do
  docker run --rm -v "$vol":/data -v "$BACKUP_DIR":/backup alpine \
    tar czf "/backup/$vol.tar.gz" -C /data .
done

# Keep only last 7 days
find /backups -name "homelab-*" -mtime +7 -delete
EOF

$ sudo chmod +x /usr/local/bin/homelab-backup.sh
```

Create one-shot service:

```bash
$ sudo tee /etc/systemd/system/homelab-backup.service > /dev/null <<'EOF'
[Unit]
Description=Homelab volume backup
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/homelab-backup.sh
EOF
```

Create daily timer:

```bash
$ sudo tee /etc/systemd/system/homelab-backup.timer > /dev/null <<'EOF'
[Unit]
Description=Run homelab backup daily

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
```

Enable and verify:

```bash
$ sudo systemctl daemon-reload
$ sudo systemctl enable --now homelab-backup.timer
Created symlink /etc/systemd/system/timers.target.wants/homelab-backup.timer -> /etc/systemd/system/homelab-backup.timer.

$ systemctl list-timers homelab-backup.timer
NEXT                         LEFT     LAST   PASSED  UNIT                  ACTIVATES
...                          ...      ...    ...     homelab-backup.timer  homelab-backup.service
```

View backup logs:

```bash
$ journalctl -u homelab-backup.service --since today
```

---

## Development

### Prek Hooks (Preferred)

```bash
# Preferred in this repo
$ prek install

# Run manually on all files
$ prek run -a

# Compatible alternative
$ pre-commit install
$ pre-commit run -a
```

### Nix Development Shell

```bash
# If you have Nix + direnv
$ direnv allow

# Or enter shell manually
$ nix develop
```

### Running Tests

```bash
# Validate Docker Compose files
$ docker compose config > /dev/null && echo "✓ Config valid"
✓ Config valid

# Test specific profile
$ docker compose --profile infra config > /dev/null
```
