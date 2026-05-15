# Agent Guide

This repo is a Docker Compose homelab. The main stack is `docker-compose.yml`, which includes `services/*.yml` plus `home-assistant/docker-compose.yml`. The Dockhand bootstrap stack is `docker-compose.pods.yml` + `services/pods.yml`.

## Source of truth
- Local bootstrap / required env behavior: `setup-dev.sh`
- Example env values: `.env.example`
- Validation contract: `.github/workflows/test-docker-compose.yml`
- Lint / formatting rules: `.pre-commit-config.yaml`
- Operator overview: `README.md`
- Architecture / profiles / routing model: `docs/architecture.md`
- Service inventory / required vars: `docs/services.md`
- Adding services / Traefik / Sablier wiring: `docs/customization.md`
- Dockhand deployment flow: `docs/dockhand.md`
- Queue-driven wake pattern: `docs/queue-driven-sleep.md`
- Failure playbook: `docs/troubleshooting.md`

## Do not edit or commit
- `.env`
- `services/.env-*`
- `services/secrets/*`
- `home-assistant/config/`
- `site/`
- `.cache/`
- `config/homepage/logs/`
- `services/config/homepage/logs/`
- `config/homepage/custom.css`
- `config/homepage/custom.js`
- `config/homepage/kubernetes.yaml`

## High-risk files
Treat these as likely to break routing or deployment:
- `docker-compose.yml`
- `docker-compose.pods.yml`
- `services/networking.yml`
- `config/traefik/traefik.yml`
- `config/traefik/dyn/*.yml`
- `home-assistant/docker-compose.yml`

## Change map
- Add a main-stack service in `services/<name>.yml`, then include it from `docker-compose.yml`
- Keep Dockhand/bootstrap changes in `docker-compose.pods.yml` and `services/pods.yml`
- Put static Traefik config in `config/traefik/traefik.yml`
- Put routes, middleware, and Sablier config in `config/traefik/dyn/*.yml`
- Home Assistant lives under `home-assistant/` but is included from the main `docker-compose.yml`
- Use lowercase, hyphenated YAML filenames
- Use uppercase snake case for env vars
- Prefer stack-local changes over repo-wide refactors
- Compose profiles are feature flags: `infra`, `apps`, `all`, `experimental`, `tunnel`

## Traefik footgun
- For the minimum Docker-label Traefik exposure without file-provider routing or Sablier, copy the pattern from `services/immich.yml`: join `traefik_public`, set `traefik.enable=true`, add a router rule, set `entrypoints=${TRAEFIK_ENTRYPOINT:-websecure}`, and set the internal service port with `traefik.http.services.<name>.loadbalancer.server.port=<port>`
- For file-provider routing, keep normal services on `traefik_public` and target the service name, as in `config/traefik/dyn/netalertx.yml`; for host-networked services such as Home Assistant, target `host.docker.internal:<port>` as in `config/traefik/dyn/ha.yml`
- If Traefik cannot reach the container, check network attachment for normal services and the file-provider target for host-networked services

## Homepage footgun
- In this repo, Homepage service entries mostly come from Docker labels, not `config/homepage/services.yaml` (currently empty)
- Minimal example is also in `home-assistant/docker-compose.yml`: add `homepage.group`, `homepage.name`, `homepage.icon`, `homepage.href`, and `homepage.description`; Homepage labels are independent from whether Traefik routing comes from Docker labels or the file provider
- For more label patterns and grouping conventions, use `docs/customization.md`
- Do not add `homepage.siteMonitor` or similar active health checks to Sablier-managed services unless you want Homepage to generate wake-up traffic and log noise

## Sablier footgun
- To enable Sablier, add `sablier.enable=true`, `sablier.group=<name>`, and a matching `sablier-<name>@file` middleware / router reference
- To disable it, remove both the service labels and the router middleware reference
- For the queue-driven wake special case, see `services/immich.yml` and `docs/queue-driven-sleep.md`

## Validation
- Run the checks defined in `.github/workflows/test-docker-compose.yml`
- Run `prek run -a`
- If you changed compose or routing, validate the affected stack config before calling the work done
