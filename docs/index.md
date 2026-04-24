---
title: Welcome
hide:
  - toc
---

# Homelab Docs

This docs set describes the repo as it exists now.

- `docker-compose.yml` is the **main stack**.
- `docker-compose.pods.yml` is the separate **Dockhand bootstrap stack**.
- Most sleep-on-request apps are routed through `config/traefik/dyn/*.yml`.
- Some services are still routed directly with Docker labels.

If you want the shortest path, start with the bootstrap stack.

---

## Try It Now

```bash title="Bootstrap Dockhand first"
# 1. Clone the repo
$ git clone https://github.com/jakob1379/homelab.git && cd homelab
Cloning into 'homelab'...
done.

# 2. Start only the control plane
$ docker compose -f docker-compose.pods.yml up -d
[+] Running 1/1
 ✔ Container homelab-pods-dockhand-1  Started

# 3. Verify the local bootstrap endpoint
$ curl -I http://localhost:3000
HTTP/1.1 200 OK
```

Then use one of these paths:

- want the repo layout and routing model first? Read [Architecture](architecture.md)
- want the live services and URLs? Read [Service Reference](services.md)
- want the Git-managed deployment path? Read [Deployment](dockhand.md)
- want to add your own app? Read [Configuration](customization.md)

---

## What You'll Find Here

<div class="grid cards" markdown>

-   🧭 **Architecture**

    ---

    Entry points, profiles, routing sources, networks, and current caveats.

    [→ Read architecture](architecture.md)

-   📦 **Services**

    ---

    Current service inventory, URLs, sleep behavior, and required variables.

    [→ Read services](services.md)

-   🛠️ **Configuration**

    ---

    Add a new service using the same Traefik, Sablier, and Homepage patterns as the active stack.

    [→ Read configuration](customization.md)

-   🐳 **Deployment**

    ---

    Bootstrap **Dockhand**, point it at this repo, and verify the routed stack.

    [→ Read deployment](dockhand.md)

-   ⚠️ **Troubleshooting**

    ---

    Missing variables, stuck Sablier routes, AdGuard port conflicts, and current media-stack footguns.

    [→ Read troubleshooting](troubleshooting.md)

-   🔁 **Queue-Driven Sleep**

    ---

    Current status: not active for **Immich** in this repo.

    [→ Read status](queue-driven-sleep.md)

</div>

---

## Current Repo Shape

```text title="Top-level stack entrypoints"
.
├── docker-compose.yml           # Main stack
├── docker-compose.pods.yml      # Dockhand bootstrap stack
├── services/                    # Stack definitions included by docker-compose.yml
├── config/traefik/dyn/          # File-provider routes and Sablier middleware
└── home-assistant/              # Home Assistant files, included from the main stack
```

There are also parked service definitions under `services/` that are not currently included from `docker-compose.yml`, including `hermes.yml` and `teable*.yml`.
