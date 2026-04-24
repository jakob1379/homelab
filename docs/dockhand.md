---
title: Deployment
---

# Deploy Through Dockhand

Use this guide for the repo's current Git-managed deployment path. The control plane is the separate `docker-compose.pods.yml` stack. The main stack still lives in `docker-compose.yml`.

Read [Architecture](architecture.md) if you want the profile and routing model first.

---

## Try It Now

```bash title="Bootstrap Dockhand on a fresh host"
# 1. Clone the repo
$ git clone https://github.com/jakob1379/homelab.git && cd homelab
Cloning into 'homelab'...
done.

# 2. Start only the pods stack
$ docker compose -f docker-compose.pods.yml up -d
[+] Running 1/1
 ✔ Container homelab-pods-dockhand-1  Started

# 3. Verify the direct bootstrap endpoint
$ curl -I http://localhost:3000
HTTP/1.1 200 OK
```

Open `http://localhost:3000`.

During bootstrap, `https://docker.${DOMAIN}` does not exist yet because the main **Traefik** stack is not running.

---

## Step 1: Prepare The Stack Variables

The main stack is not optional about TLS inputs. `services/networking.yml` requires:

- `ACME_EMAIL`
- `CF_DNS_API_TOKEN`

Start with a real `.env`.

```bash title="Create the root .env file"
$ cat > .env <<'EOF'
TZ=Europe/Copenhagen
DOMAIN=lab.example.com
ACME_EMAIL=you@example.com
CF_DNS_API_TOKEN=your_cloudflare_token
DOCKHAND_DATA_DIR=/opt/dockhand
RUSTFS_ACCESS_KEY=rustadmin
RUSTFS_SECRET_KEY=rustadmin
EOF
```

Then add the app secrets required by the services you plan to run.

```text title="Common app variables"
IMMICH_DB_PASSWORD=...
LISTMONK_db__password=...
PAPERLESS_DBPASS=...
PAPERLESS_ADMIN_PASSWORD=...
PAPERLESS_SECRET_KEY=...
NEXTAUTH_SECRET=...
MEILI_MASTER_KEY=...
SPEEDTEST_APP_KEY=...
```

Optional values for current features:

```text title="Optional variables"
KARAKEEP_OPENAI_API_KEY=...
KARAKEEP_OAUTH_WELLKNOWN_URL=...
KARAKEEP_OAUTH_CLIENT_ID=...
KARAKEEP_OAUTH_CLIENT_SECRET=...
KARAKEEP_OAUTH_PROVIDER_NAME=OIDC
IMMICH_API_KEY=...
IMMICH_URL=http://immich-server:2283
EXTERNAL_IMMICH_URL=https://photos.lab.example.com
AI_API_KEY=...
AI_BASE_URL=https://api.openai.com/v1
AI_MODEL=gpt-4o-mini
```

### Current media caveat

`setup-dev.sh` still flags these for `--profile all`:

```text
OPENVPN_USER=...
OPENVPN_PASSWORD=...
```

That matches the bootstrap script today, even though the active media stack no longer runs **Gluetun**.

---

## Step 2: Bootstrap The Control Plane

```bash title="Start the separate Dockhand stack"
$ docker compose -f docker-compose.pods.yml up -d
[+] Running 1/1
 ✔ Container homelab-pods-dockhand-1  Started
```

Use a real host path for `DOCKHAND_DATA_DIR`, such as `/opt/dockhand`. That matters for Git-managed stacks with relative bind mounts.

---

## Step 3: Create The Git-Managed Stack In Dockhand

Use `docker-compose.yml` as the compose entrypoint.

Recommended settings:

| Setting | Value |
|---|---|
| **Name** | `homelab` |
| **Repository URL** | your fork or this repo URL |
| **Reference** | `refs/heads/main` |
| **Compose path** | `docker-compose.yml` |

Pass the same variables from the previous step into the Dockhand-managed stack.

This repo uses `${VAR:?message}` guards heavily. If a required variable is missing, Compose render fails before deployment completes.

---

## Step 4: Verify The Rerouted Result

Once Dockhand deploys the main stack, the bootstrap container is still separate, but **Traefik** can now reach it over `traefik_public`.

```bash title="Verify the main routed stack"
$ curl -k https://whoami.lab.example.com
Hostname: homelab-whoami-1
IP: 172.20.0.2

$ curl -I https://docker.lab.example.com
HTTP/2 200
```

At that point:

- `http://localhost:3000` is still the direct bootstrap endpoint
- `https://docker.${DOMAIN}` is the routed endpoint through **Traefik**

---

## DNS And TLS

The current repo expects this model in production:

1. **Cloudflare** handles DNS-01 proof for **Let's Encrypt**
2. **AdGuard** resolves `*.${DOMAIN}` to the homelab host
3. **Traefik** terminates TLS and routes the request

### Cloudflare token permissions

- `Zone:Read`
- `DNS:Edit`

### Example wildcard records in AdGuard

```text title="AdGuard records"
A  *.lab.example.com  100.90.12.34
A  lab.example.com    100.90.12.34
```

### Verify the certificate path

```bash title="Verify DNS, routing, and TLS"
$ dig +short whoami.lab.example.com
100.90.12.34

$ curl -k https://whoami.lab.example.com
Hostname: homelab-whoami-1

$ echo | openssl s_client -connect whoami.lab.example.com:443 -servername whoami.lab.example.com 2>/dev/null | openssl x509 -noout -subject -issuer
subject=CN = whoami.lab.example.com
issuer=C = US, O = Let's Encrypt, CN = R12
```

If you still see the default Traefik cert, check **Traefik** logs before blaming DNS.

---

## Common Checks

```bash title="Check both stacks"
$ docker compose -f docker-compose.pods.yml ps
$ docker compose ps traefik whoami
$ docker compose logs traefik --tail 100
```

Use [Troubleshooting](troubleshooting.md) for failure-specific steps.
