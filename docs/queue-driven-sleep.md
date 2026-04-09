# Queue-Driven Sleep Pattern

Use this pattern when a service has **background workers** and a **queue** (for example Immich), but you still want to reduce idle resource usage.

Wake is not limited to a browser request. In this pattern, wake can be triggered by:

- HTTP request through Traefik/Sablier
- Cron pre-warm schedule
- Queue backlog monitor calling Sablier API

This is not one-size-fits-all. You must tune it per stack.

## Try It Now

This verifies the wake-up path without waiting for user traffic.

```bash
# 1. Start stack with experimental queue monitor
$ docker compose --profile all --profile experimental up -d
[+] Running ...
 ✔ Container homelab-traefik-1  Started
 ✔ Container homelab-sablier-1  Started
 ...

# 2. Check always-on control plane
$ docker compose ps immich-server redis immich-postgres sablier
NAME                    IMAGE                                STATUS
homelab-immich-server-1 ghcr.io/immich-app/immich-server:release Up
homelab-redis-1         redis:7-alpine                       Up
homelab-immich-postgres-1 pgvector/pgvector:pg17            Up
homelab-sablier-1       sablierapp/sablier:1.8.1            Up

# 3. Simulate idle workers
$ docker compose stop immich-microservices immich-machine-learning

# 4. Trigger a worker session through Sablier API
$ curl -i "http://localhost:10000/api/strategies/blocking?group=immich-workers&session_duration=10m&timeout=4m"
HTTP/1.1 200 OK
X-Sablier-Session-Status: ready
...

# 5. Confirm workers are back
$ docker compose ps immich-microservices immich-machine-learning
NAME                               IMAGE                                      STATUS
homelab-immich-microservices-1     ghcr.io/immich-app/immich-server:release  Up
homelab-immich-machine-learning-1  ghcr.io/immich-app/immich-machine-learning:release Up
```

## The Pattern

### 1) Keep control plane always on

Never sleep these components:

- API entrypoint (`immich-server`)
- Queue store (`redis`)
- Database (`immich-postgres`)
- Sablier + Traefik

If you sleep these, jobs either never trigger or wake-up logic cannot run.

### 2) Put only workers in a Sablier group

Workers should share a dedicated group (`immich-workers`) so they start and stop together.

- `immich-microservices`
- `immich-machine-learning`

### 3) Add queue-aware wake logic

Because queue jobs are not HTTP requests, add a small monitor that polls queue depth and calls Sablier when backlog exists.

This repo does that with `immich-queue-monitor` under the `experimental` profile.

## Not One-Size-Fits-All

Build one policy per stack or service group. Do not copy one timeout/trigger set everywhere.

| Stack type | Keep always on | Sleep candidates | Wake trigger |
|---|---|---|---|
| HTTP-only tools | Traefik + Sablier | UI service | HTTP access via Sablier middleware |
| Queue workers | DB + queue + monitor | Workers | Queue backlog monitor calling Sablier API |
| Hybrid API + queue | DB + queue + monitor | Worker group, sometimes API group | HTTP access + queue backlog + optional scheduled pre-warm |
| Webhook/event ingest | Queue + receiver (or durable ingress) | Workers only | Queue backlog or webhook retries |

If incoming events are not retryable, keep the receiver always on.

## Trigger Channels You Can Combine

Use one or more of these triggers per group:

1. **HTTP access trigger**: Traefik middleware wakes the group when users access the route.
2. **Queue backlog trigger**: monitor checks queue depth and extends a worker session.
3. **Scheduled pre-warm trigger**: cron wakes group before expected traffic windows.
4. **Manual ops trigger**: admin endpoint/script for maintenance windows.

## Scheduled Wakeups (Pre-Warm)

Use scheduled wakeups for predictable usage windows, imports, or nightly tasks.

```bash
# Wake workers for 20 minutes
$ curl -i "http://localhost:10000/api/strategies/blocking?group=immich-workers&session_duration=20m&timeout=4m"
HTTP/1.1 200 OK
X-Sablier-Session-Status: ready
```

Host cron example:

```bash
# Every day at 21:00, pre-warm Immich workers
$ crontab -l
0 21 * * * curl -fsS "http://localhost:10000/api/strategies/blocking?group=immich-workers&session_duration=30m&timeout=4m" >/dev/null
```

## Full Sleep/Wake Cycle (Hybrid Pattern)

This is the cycle you asked for when a service can sleep, wake, enqueue work, then sleep again:

1. **Idle state**: producer/API group and worker group are stopped.
2. **Wake**: HTTP access or scheduled pre-warm starts producer/API group.
3. **Enqueue**: producer writes jobs to queue.
4. **Process**: queue monitor detects backlog and starts/extents worker group session.
5. **Active use**: middleware keeps producer/API session alive while there is user traffic.
6. **Cooldown**: no traffic and no backlog, sessions expire, groups stop.
7. **Repeat**: next access/schedule/backlog triggers wake again.

This cycle only works safely when:

- wake path is reliable,
- queue is durable,
- producer events are retryable or buffered,
- stop/start latency is acceptable for your users.

## Current Immich Mapping

- Worker labels: `services/immich.yml`
  - `sablier.enable=true`
  - `sablier.group=immich-workers`
- Queue monitor: `services/immich.yml`
  - `immich-queue-monitor`
  - Calls Sablier API with `group=immich-workers`
- Worker router middleware: `config/traefik/dyn/immich.yml`
  - `immich-workers-sablier`

## Tuning Knobs

Start with these values and tune later:

- `CHECK_INTERVAL=15` seconds
- `EXTEND_DURATION=10m`
- `BLOCKING_TIMEOUT=4m`

If workers flap too often, increase `EXTEND_DURATION`.
If wake-up feels slow, reduce `CHECK_INTERVAL` carefully.

Use different values per stack. Do not reuse Immich values for every workload.

## Failure Modes and Fast Checks

```bash
# Queue monitor running?
$ docker compose ps immich-queue-monitor

# Queue monitor actually finding jobs?
$ docker compose logs immich-queue-monitor --tail 50

# Sablier API reachable from monitor path?
$ docker compose exec immich-queue-monitor wget -qO- "http://sablier:10000/healthz"

# Redis queue keys present?
$ docker compose exec redis redis-cli --scan --pattern "immich_bull:*"
```

## Is There a Better General Approach Than Sablier?

Short answer: **for Docker Compose + Traefik, Sablier is still the practical choice**.

For larger systems, better options exist but require platform changes:

- **KEDA (Kubernetes)**: best for queue-driven autoscaling and scale-to-zero on event sources (Redis, RabbitMQ, Kafka, etc.)
- **KEDA HTTP Add-on (Kubernetes)**: HTTP scale-to-zero with request buffering layer
- **Knative Serving (Kubernetes)**: mature HTTP serverless model with scale-to-zero

If you stay on Docker Compose, keep Sablier and use this queue-monitor pattern.

## Recommendation

- Keep Sablier for user-facing HTTP apps and grouped workers.
- Keep DB/queue/control plane always on.
- Use queue monitor only where queue-driven wake is needed.
- Move to KEDA/Knative only if you are ready to migrate to Kubernetes.
- Define one sleep policy per stack group (media, photos, docs, admin) and tune independently.
