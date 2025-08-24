# Homelab

[![Docs — DeepWiki](https://img.shields.io/badge/Documentation-000?logo=googledocs&logoColor=FFE165&style=for-the-badge)](https://deepwiki.com/jakob1379/homelab)

Infrastructure-as-code for my homelab running on Docker Swarm, fronted by Traefik with automatic TLS via Cloudflare DNS. This repo contains the base stack (reverse proxy, auth helpers, DNS, object storage, etc.) and a set of optional app stacks.

Note: Hostnames and some environment defaults are tailored to my domain (jgalabs.dk). If you fork or reuse this, replace them with your own domain and settings.


## Contents

- Base stack (basestack/)
  - Traefik reverse proxy + ACME (Cloudflare DNS challenge)
  - Sablier for on-demand service autoscaling from 0 replicas
  - Traefik Forward Auth (OIDC-ready)
  - AdGuard Home (DNS)
  - Optional: MinIO (S3-compatible object storage), PostgreSQL, Shepherd (image updater)
- App stacks (services/)
  - CloudBeaver (web DB admin)
  - IT Tools (collection of handy tools)
  - Listmonk (newsletter/mailing list manager)
  - Hoarder (self-hosted bookmarker/archiver) with Meilisearch + headless Chrome
  - Stirling-PDF (PDF toolbox)
  - Teable (Airtable-like) with Redis + one-shot migration/bucket jobs
  - Portainer (UI for Docker/Swarm) + Agent
- Home Assistant (home-assistant/ docker-compose for standalone usage)


## Quick start

Prerequisites
- Docker Engine and Docker Swarm (docker swarm init)
- A domain and DNS managed by Cloudflare (for ACME DNS-01)
- Ability to create Docker secrets
- For direnv + Nix (optional dev tooling): direnv and Nix installed

Create Swarm overlay network
- docker network create --driver overlay traefik_public

Required secrets (examples)
- Cloudflare DNS token (for Traefik ACME)
  - echo -n 'your_cf_dns_api_token' | docker secret create cf_dns_api_token -
- PostgreSQL admin user and password (for basestack/postgres.yml)
  - echo -n 'postgres' | docker secret create postgres_admin_user -
  - echo -n 'strongpassword' | docker secret create postgres_password -
- Shepherd registry password (for basestack/shepherd.yml)
  - echo -n 'ghcr_or_dockerhub_password' | docker secret create shepherd_registry_password -

Deploy base stack (Traefik, Sablier, etc.)
- cd basestack
- Ensure .env has CF_API_EMAIL set (already present here)
- docker stack deploy -c web.yml web
- Optional:
  - docker stack deploy -c minio.yml minio
  - docker stack deploy -c postgres.yml db
  - docker stack deploy -c shepherd.yml upkeep

Deploy app stacks (pick what you need)
Many services are configured with replicas: 0 and a Sablier middleware. They will scale up automatically on first request and scale back down after inactivity.
- CloudBeaver
  - docker stack deploy -c services/cloudbeaver.yml cloudbeaver
- IT Tools
  - docker stack deploy -c services/it-tools.yml ittools
- Listmonk
  - Create services/.env-listmonk and set DB credentials (see below)
  - docker stack deploy -c services/listmonk.yml listmonk
- Hoarder (+ Meilisearch + Chrome)
  - Create services/.env-hoarder (set Meilisearch key, app secrets)
  - docker stack deploy -c services/hoarder.yml hoarder
- Stirling-PDF
  - Create services/.env-stirling if you need extra env
  - docker stack deploy -c services/stirling.yml stirling
- Teable (+ Redis)
  - Create services/.env-teable (DB URL, Redis, S3 creds)
  - docker stack deploy -c services/teable.yml teable
  - One-time jobs:
    - docker stack deploy -c services/teable-migrate.yml teable-migrate
    - This runs DB migrations and creates S3 buckets (public/private) via MinIO client
- Portainer (+ Agent)
  - docker stack deploy -c services/portainer-stack.yml portainer


## Domains and routing

Traefik derives default host rules from stack service names and is also configured with explicit file-based routers (basestack/traefik/dyn/*). Update hostnames to match your domain if you’re not using jgalabs.dk.

Examples in dyn configs
- cbeaver.jgalabs.dk → CloudBeaver
- it.jgalabs.dk → IT Tools
- pods.jgalabs.dk → Portainer
- pdf.jgalabs.dk → Stirling-PDF
- teable.jgalabs.dk → Teable
- whoami.jgalabs.dk → Traefik whoami test
- s3.jgalabs.dk → MinIO S3 API (via labels in basestack/minio.yml)

TLS
- ACME DNS-01 via Cloudflare is enabled. Set the cf_dns_api_token secret and CF_API_EMAIL (.env).


## Environment files you must provide

These files are referenced by the stacks but not stored in the repo. Create them next to the stack files that reference them.

- basestack/.env-minio (used by basestack/minio.yml)
  - MINIO_ROOT_USER=...
  - MINIO_ROOT_PASSWORD=...
- services/.env-listmonk (used by services/listmonk.yml)
  - LISTMONK_db__password=...
  - Optional: any LISTMONK_app__ or db__ overrides
- services/.env-hoarder (used by services/hoarder.yml and meilisearch)
  - MEILI_MASTER_KEY=...
  - HOARDER secrets, auth, etc.
- services/.env-stirling (used by services/stirling.yml)
  - Optional OCR language packs, etc.
- services/.env-teable (used by services/teable*.yml)
  - DATABASE_URL=postgres://user:pass@host:5432/dbname
  - REDIS_PASSWORD=...
  - MINIO_ACCESS_KEY=...
  - MINIO_SECRET_KEY=...
  - S3_ENDPOINT=https://s3.your-domain.tld (matches minio router host)

Adjust names/variables as your setups require.


## Development environment

This repo includes a Nix flake and pre-commit setup for YAML hygiene and basic security checks.
- If you use direnv + Nix
  - direnv allow
  - nix develop (or let direnv load the devShell)
- Tools in devShell
  - pre-commit, gitleaks, yamllint, yamlfix
- Set up pre-commit hooks
  - pre-commit install
  - pre-commit run -a


## How it works (high level)

- Traefik (basestack/web.yml) publishes 80/443 and handles ACME via Cloudflare DNS-01
- File provider config in basestack/traefik/dyn adds named routers/middlewares
- Sablier plugin brings services up from 0 replicas on first hit and idles them back down
- Many service stacks opt into Sablier via labels and replicas: 0
- MinIO provides S3-compatible storage; Teable’s one-shot job creates public/private buckets
- PostgreSQL runs in its own stack and can be used by apps like Listmonk/Teable


## Home Assistant

The home-assistant/ directory contains a docker-compose.yml and configuration.yaml for running Home Assistant separately from Swarm.


## Documentation

Full documentation and notes are maintained on DeepWiki:
- https://deepwiki.com/jakob1379/homelab

