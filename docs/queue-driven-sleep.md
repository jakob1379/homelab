# Queue-Driven Sleep Pattern

This pattern is **not active** in the current repo.

The old Immich worker wake flow is gone from the live stack.

---

## Try It Now

```bash title="Inspect the active Immich stack"
# 1. Start the Immich stack
$ docker compose --profile apps up -d immich-server immich-microservices immich-machine-learning
[+] Running ...
 ✔ Container homelab-immich-server-1            Started
 ✔ Container homelab-immich-microservices-1     Started
 ✔ Container homelab-immich-machine-learning-1  Started

# 2. Verify the routed service
$ curl -k https://photos.traefik.me
<!doctype html>
...
```

That matches the current source files:

- `services/immich.yml` exposes `immich-server` directly with Docker labels
- `immich-microservices` stays running
- `immich-machine-learning` stays running
- there is no `immich-queue-monitor` service
- there is no Immich-specific Sablier worker group

---

## Current State

The active source of truth for **Immich** is:

- `services/immich.yml`
- `services/media.yml` for **Immich Power Tools**
- [Service Reference](services.md)

If you want queue-driven wake behavior again, that is a new design task. Do not assume it already exists.
