---
title: Configuration
---

# Customize The Stack

Use this guide when you want to add a service that behaves like the current repo, not like the older docs. The recommended path is:

1. create a stack file under `services/`
2. decide whether the route belongs in **Traefik file-provider config** or direct **Docker labels**
3. add **Homepage** labels if you want dashboard discovery
4. validate with the same commands the repo uses in CI

Read [Architecture](architecture.md) first if you are unsure which routing pattern to copy.

---

## Try It Now

This example adds a small sleep-managed service using the same pattern as **IT Tools**, **Homepage**, and **Karakeep**.

### Step 1: create the stack file

```bash title="Create services/custom-demo.yml"
$ cat > services/custom-demo.yml <<'EOF'
---
services:
  demo:
    profiles: [apps, all]
    image: nginx:alpine
    networks: [traefik_public]
    labels:
      - sablier.enable=true
      - sablier.group=demo
      - homepage.group=Utilities
      - homepage.name=Demo
      - homepage.icon=nginx.png
      - homepage.href=https://demo.${DOMAIN:-traefik.me}
      - homepage.description=Small demo service
    restart: unless-stopped
networks:
  traefik_public:
    name: traefik_public
    driver: bridge
    attachable: true
EOF
```

### Step 2: create the route file

```bash title="Create config/traefik/dyn/demo.yml"
$ cat > config/traefik/dyn/demo.yml <<'EOF'
---
http:
  routers:
    demo:
      rule: Host(`demo.{{ env "DOMAIN" }}`)
      entrypoints: [websecure]
      service: demo
      middlewares: [sablier-demo@file, startup-retry@file]
  services:
    demo:
      loadBalancer:
        servers:
          - url: http://demo:80/
  middlewares:
    sablier-demo:
      plugin:
        sablier:
          group: demo
          dynamic:
            displayName: Demo
            refreshFrequency: 2s
            showDetails: 'true'
            theme: ghost
          sablierUrl: http://sablier:10000
          sessionDuration: 30m
EOF
```

### Step 3: include the file from `docker-compose.yml`

Add this line to the root include list:

```yaml title="docker-compose.yml"
include:
  - services/custom-demo.yml
```

### Step 4: validate and start it

```bash title="Validate and run the demo service"
# 1. Validate the combined main stack
$ docker compose --profile all config > /dev/null

# 2. Start the new app
$ docker compose --profile apps up -d demo
[+] Running 1/1
 ✔ Container homelab-demo-1  Started

# 3. Test the route
$ curl -k https://demo.traefik.me
<!DOCTYPE html>
<html>
...
```

---

## Choose The Right Routing Pattern

This is the decision that matters.

### Use `config/traefik/dyn/*.yml` when

- you want **Sablier** sleep-on-request
- you want `startup-retry@file`
- you want an explicit middleware chain
- you want the route definition separate from the service definition

This is the normal pattern for:

- **AnythingLLM**
- **Homepage**
- **Karakeep**
- **Paperless-ngx**
- **Seerr**
- **Jellyfin**

### Use direct Docker labels when

- the service should stay up
- the route is simple
- the service does not need a file-provider middleware chain

This is the normal pattern for:

- **Immich**
- **AdGuard**
- **Dockhand**
- **Home Assistant**
- **Speedtest Tracker**

---

## Pattern A: Sleep-Managed Service

Copy this when you want the same behavior as `keep`, `home`, or `ittools`.

### Service definition

```yaml title="services/myapp.yml"
services:
  myapp:
    profiles: [apps, all]
    image: myapp:latest
    networks: [traefik_public]
    labels:
      - sablier.enable=true
      - sablier.group=myapp
      - homepage.group=Utilities
      - homepage.name=MyApp
      - homepage.icon=myapp.png
      - homepage.href=https://myapp.${DOMAIN:-traefik.me}
      - homepage.description=What this app does
    restart: unless-stopped
```

### Route definition

```yaml title="config/traefik/dyn/myapp.yml"
http:
  routers:
    myapp:
      rule: Host(`myapp.{{ env "DOMAIN" }}`)
      entrypoints: [websecure]
      service: myapp
      middlewares: [sablier-myapp@file, startup-retry@file]
  services:
    myapp:
      loadBalancer:
        servers:
          - url: http://myapp:8080/
  middlewares:
    sablier-myapp:
      plugin:
        sablier:
          group: myapp
          dynamic:
            displayName: MyApp
            refreshFrequency: 2s
            showDetails: 'true'
            theme: ghost
          sablierUrl: http://sablier:10000
          sessionDuration: 30m
```

Two things must match exactly:

- `sablier.group=myapp`
- `middlewares.sablier-myapp.plugin.sablier.group=myapp`

If they do not match, the route will not wake correctly.

---

## Pattern B: Always-On Service With Direct Labels

Copy this when you want the same style as **Home Assistant** or **Immich**.

```yaml title="home-assistant/docker-compose.yml"
services:
  ha:
    profiles: [apps, all, service]
    image: homeassistant/home-assistant:2026.4.1
    networks: [traefik_public]
    labels:
      - traefik.enable=true
      - traefik.http.routers.ha.rule=Host(`ha.${DOMAIN:-traefik.me}`)
      - traefik.http.routers.ha.entrypoints=websecure
      - traefik.http.services.ha.loadbalancer.server.port=8123
```

Use this pattern when you do not need **Sablier** and do not want a file-provider route.

---

## Homepage Labels

Most Homepage entries in this repo come from Docker labels, not `config/homepage/services.yaml`.

`config/homepage/services.yaml` is currently empty.

Use labels like this:

```yaml title="Homepage labels"
labels:
  - homepage.group=Utilities
  - homepage.name=MyApp
  - homepage.icon=myapp.png
  - homepage.href=https://myapp.${DOMAIN:-traefik.me}
  - homepage.description=What this app does
```

Use `homepage.siteMonitor` only for always-on services. If you add it to a **Sablier** route, Homepage can generate wake-up traffic and noisy logs.

---

## Validation Commands

Run the same checks the repo points at in `AGENTS.md` and CI.

```bash title="Validate the stack definitions"
# Main stack render
$ docker compose --profile all config > /dev/null

# Bootstrap stack render
$ docker compose -f docker-compose.pods.yml config > /dev/null

# Repo hooks
$ prek run -a
```

If you changed static Traefik config, restart Traefik after validation.

```bash title="Restart Traefik after static-config changes"
$ docker compose restart traefik
```

Changes under `config/traefik/dyn/` are watched automatically by the file provider.

---

## Common Mistakes

### Missing `traefik_public`

This is the usual reason for 502s.

```bash title="Check that the service joined traefik_public"
$ docker network inspect traefik_public
[
  ...
]
```

### Wrong internal port

The `loadBalancer.server.port` or URL must match the port the app actually listens on.

### Sablier labels without a matching middleware

This is exactly the kind of partial wiring that currently exists for **Listmonk**. Do not copy it unless you want the same behavior.

### Documenting parked files as active services

`services/hermes.yml` and `services/teable*.yml` are not active until they are added to `docker-compose.yml`.
