# Queue-Driven Sleep Pattern

Use this pattern when a service has **background workers** and a **queue** (for example Immich), but you still want to reduce idle resource usage.

Wake is not limited to a browser request. In this pattern, wake can be triggered by:

- HTTP request through Traefik/Sablier for user-facing services
- Cron pre-warm schedule
- Queue backlog monitor calling Sablier API

This is not one-size-fits-all. You must tune it per stack.

## Try It Now

This verifies the wake-up path without waiting for user traffic.

```bash title="Verify the Immich worker wake path"
# 1. Start the Immich stack
$ docker compose --profile all up -d
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
$ docker compose stop immich-microservices

# 4. Trigger a worker session through the monitor path
$ docker compose exec immich-queue-monitor curl -i "http://sablier:10000/api/strategies/blocking?group=immich-workers&session_duration=10m&timeout=90s"
HTTP/1.1 200 OK
X-Sablier-Session-Status: ready
...

# 5. Confirm the worker is back and ML stayed up
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

The public Immich route stays `photos.${DOMAIN}` via `config/traefik/dyn/immich.yml`; `immich-server` is not exposed through Docker-provider routing.

### 2) Put only queue-woken workers in a Sablier group

Only `immich-microservices` belongs in `immich-workers`.

`immich-machine-learning` stays always on.

### 3) Add queue-aware wake logic

Because queue jobs are not HTTP requests, add a small monitor that polls queue depth and calls Sablier when backlog exists.

This repo does that with `immich-queue-monitor` as part of the Immich stack.

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

```bash title="Trigger a worker session manually"
# Wake workers for 20 minutes
$ docker compose exec immich-queue-monitor curl -i "http://sablier:10000/api/strategies/blocking?group=immich-workers&session_duration=20m&timeout=90s"
HTTP/1.1 200 OK
X-Sablier-Session-Status: ready
```

Host cron example:

```bash title="Host cron pre-warm example"
# Every day at 21:00, pre-warm Immich workers
$ crontab -l
0 21 * * * docker compose exec -T immich-queue-monitor curl -fsS "http://sablier:10000/api/strategies/blocking?group=immich-workers&session_duration=30m&timeout=90s" >/dev/null
```

## Full Sleep/Wake Cycle (Hybrid Pattern)

This is the cycle you asked for when a service can sleep, wake, enqueue work, then sleep again:

1. **Idle state**: worker group is stopped while API/control-plane services stay up.
2. **Enqueue**: API or scheduled work writes jobs to queue.
3. **Wake**: queue monitor detects backlog and starts or extends the worker group session.
4. **Process**: workers drain queued jobs.
5. **Cooldown**: no backlog, session expires, worker group stops.
6. **Repeat**: next backlog or pre-warm event triggers wake again.

This cycle only works safely when:

- wake path is reliable,
- queue is durable,
- producer events are retryable or buffered,
- stop/start latency is acceptable for your users.

## Current Immich Mapping

- Worker labels: `services/immich.yml`
  - `immich-microservices` only
- Queue monitor: `services/immich.yml`
  - `immich-queue-monitor`
  - Calls Sablier API with `group=immich-workers`
- Traefik: `config/traefik/dyn/immich.yml`
  - public `photos.${DOMAIN}` route only

## Tuning Knobs

Start with these values and tune later:

- `CHECK_INTERVAL=15` seconds
- `EXTEND_DURATION=10m`
- `BLOCKING_TIMEOUT=90s`

If workers flap too often, increase `EXTEND_DURATION`.
If wake-up feels slow, reduce `CHECK_INTERVAL` carefully.

Use different values per stack. Do not reuse Immich values for every workload.

## Failure Modes and Fast Checks

```bash title="Fast checks for the queue-driven wake path"
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

- Keep Sablier for user-facing HTTP apps and the queue-woken worker group.
- Keep DB/queue/control plane always on.
- Use queue monitor only where queue-driven wake is needed.
- Move to KEDA/Knative only if you are ready to migrate to Kubernetes.
- Define one sleep policy per stack group (media, photos, docs, admin) and tune independently.
