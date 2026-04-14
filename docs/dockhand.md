---
title: Deployment
---

# Deploy Through Dockhand

Use this guide for the Git-managed deployment path in this repo. Start the separate `docker-compose.pods.yml` bootstrap stack, open **Dockhand** on port `3000`, then let **Dockhand** deploy **Traefik**, **AdGuard**, and the rest of the main homelab stack from Git. For service layout, read [Service Reference](services.md). For routing and profiles, read [Architecture](architecture.md). For custom stacks, read [Configuration](customization.md). For failures, use [Troubleshooting](troubleshooting.md).

---

## Try It Now

This is the shortest working path from a fresh clone to a fully deployed stack:

```bash title="Fresh-host deployment path"
# 1. Clone and prepare the local env files
$ git clone https://github.com/jakob1379/homelab.git && cd homelab

$ ./setup-dev.sh

# 2. Set your real deployment domain and required secrets
$ cat > .env <<'EOF'
TZ=Europe/Copenhagen
DOMAIN=lab.example.com
ACME_EMAIL=you@example.com
CF_DNS_API_TOKEN=your_cf_api_token
DOCKHAND_DATA_DIR=/opt/dockhand
EOF

# 3. Bootstrap Dockhand
$ docker compose -f docker-compose.pods.yml up -d
```

Open `http://localhost:3000`, create a repository-backed stack that points back to this repo, then verify the routed stack after the full deploy:

```bash title="Verify the routed stack after the full deploy"
$ curl -k https://whoami.lab.example.com
Hostname: homelab-whoami-1
IP: 172.20.0.2
```

Dockhand should use a real host path such as `/opt/dockhand` for `DOCKHAND_DATA_DIR` so Git-managed stacks with relative bind mounts resolve correctly when Docker creates the target containers.

!!! note
    During bootstrap, **Traefik** is not running yet, so `https://docker.${DOMAIN}` does not exist. Use `http://localhost:3000` or `http://<server-ip>:3000` until Dockhand deploys the full stack.

---

## Why The Bootstrap Uses A Separate Compose Stack

The separate `docker-compose.pods.yml` stack provides a small control plane:

1. Start **Dockhand** with `docker compose -f docker-compose.pods.yml up -d`.
2. Use **Dockhand** to deploy `docker-compose.yml` as the real homelab stack.
3. Let that stack create **Traefik**, **AdGuard**, **RustFS**, and the app stacks, then route traffic to the still-separate `dockhand` container.

This matters for two reasons:

- You do not need **Traefik** running before you can manage the host.
- The deployment story matches the repo: **Dockhand** is the bootstrap control plane, not an app that must already be routed before it can manage anything.

---

## Step 1: Prepare The Repo

You need the following before the full deploy works:

- A root `.env` with `TZ`, `DOMAIN`, `ACME_EMAIL`, `CF_DNS_API_TOKEN`, and the app secrets required by the profiles you plan to run
- `DOCKHAND_DATA_DIR` set to a real host path such as `/opt/dockhand` if you want Dockhand Git stacks to support relative bind mounts
- Any shell or direnv-provided values you intentionally keep out of `.env`, such as `SPEEDTEST_APP_KEY`

```bash title="Create the root deployment file"
$ cat > .env <<'EOF'
TZ=Europe/Copenhagen
DOMAIN=lab.example.com
ACME_EMAIL=you@example.com
CF_DNS_API_TOKEN=your_cf_api_token
DOCKHAND_DATA_DIR=/opt/dockhand
EOF
```

If you want media automation, add the ProtonVPN credentials before deployment:

```bash title="Optional ProtonVPN credentials"
$ cat >> .env <<'EOF'
OPENVPN_USER=your_proton_openvpn_username
OPENVPN_PASSWORD=your_proton_openvpn_password
VPN_SERVER_COUNTRIES=Netherlands
EOF
```

---

## Step 2: Bootstrap Dockhand

The `docker-compose.pods.yml` stack exists specifically for the deployment control plane.

```bash title="Start the bootstrap control plane"
$ docker compose -f docker-compose.pods.yml up -d
```

Then open `http://localhost:3000` and connect Dockhand to the local Docker socket.

---

## Step 3: Let Dockhand Deploy The Homelab

Use the same repository as the source of truth.

Recommended stack settings:

| Setting | Value |
|---------|-------|
| **Name** | `homelab` |
| **Repository URL** | `https://github.com/yourusername/homelab` |
| **Repository reference** | `refs/heads/main` |
| **Compose path** | `docker-compose.yml` |

Make sure the repository-backed stack receives at least these environment variables:

```text title="Required stack variables"
DOMAIN=lab.example.com
ACME_EMAIL=you@example.com
CF_DNS_API_TOKEN=your_cf_api_token
IMMICH_DB_PASSWORD=...
LISTMONK_db__password=...
PAPERLESS_DBPASS=...
PAPERLESS_ADMIN_PASSWORD=...
PAPERLESS_SECRET_KEY=...
NEXTAUTH_SECRET=...
MEILI_MASTER_KEY=...
KARAKEEP_OPENAI_API_KEY=...  # optional, only if you want Karakeep AI features backed by OpenAI
# Optional Karakeep OIDC passthrough
# KARAKEEP_OAUTH_WELLKNOWN_URL=https://idp.example.com/.well-known/openid-configuration
# KARAKEEP_OAUTH_CLIENT_ID=...
# KARAKEEP_OAUTH_CLIENT_SECRET=...
# KARAKEEP_OAUTH_PROVIDER_NAME=OIDC
RUSTFS_ACCESS_KEY=...
RUSTFS_SECRET_KEY=...
SPEEDTEST_APP_KEY=...
```

If you plan to use media downloads, also add:

```text title="Optional media variables"
OPENVPN_USER=your_proton_openvpn_username
OPENVPN_PASSWORD=your_proton_openvpn_password
VPN_SERVER_COUNTRIES=Netherlands
```

This repo fails fast with `${VAR:?message}` checks. If one of the required variables is missing from the Dockhand-managed stack environment, Compose rendering fails before the stack deploy completes.

The first full deploy brings up:

- **Traefik**
- **Sablier**
- **AdGuard**
- **RustFS**
- app stacks such as **Immich** and **Paperless**

The bootstrap `docker-compose.pods.yml` stack keeps running separately. Once the main stack brings up **Traefik**, the `docker.${DOMAIN}` route points at that bootstrap container over the shared `traefik_public` network.

---

## Step 4: Configure DNS And TLS For Production

This repo uses **Cloudflare DNS-01** for certificate issuance and **VPN DNS** for client resolution.

Before you treat the stack as production-ready, make sure you:

- bootstrap the host with `docker compose -f docker-compose.pods.yml up -d`
- deploy the full homelab through **Dockhand**
- configure **Cloudflare** DNS-01, **NetBird** DNS, and **AdGuard** wildcard routing
- verify `https://whoami.${DOMAIN}` after the full deploy

The roles are separate:

- **Cloudflare** proves domain ownership to **Let's Encrypt**
- **NetBird** tells VPN clients which DNS resolver to use
- **AdGuard** resolves `*.${DOMAIN}` to the homelab server's VPN IP

Resolution path:

`VPN client -> NetBird DNS settings -> AdGuard -> Traefik`

### Cloudflare token permissions

Your Cloudflare token needs:

- `Zone:Read`
- `DNS:Edit`

### AdGuard wildcard records

Point your wildcard and apex records to the homelab host's VPN IP:

```text title="AdGuard wildcard records"
A  *.lab.example.com  100.90.12.34
A  lab.example.com    100.90.12.34
```

### Verify certificate issuance

```bash title="Verify DNS, routing, and the served certificate"
$ dig +short whoami.lab.example.com
100.90.12.34

$ curl -k https://whoami.lab.example.com
Hostname: homelab-whoami-1

$ echo | openssl s_client -connect whoami.lab.example.com:443 -servername whoami.lab.example.com 2>/dev/null | openssl x509 -noout -subject -issuer
subject=CN = whoami.lab.example.com
issuer=C = US, O = Let's Encrypt, CN = R12
```

If you see `TRAEFIK DEFAULT CERT`, the router is not inheriting or requesting the ACME resolver correctly. Check the live router config and Traefik logs before touching DNS.

---

## Common Bootstrap Checks

```bash title="Check the bootstrap and full-stack state"
$ docker compose -f docker-compose.pods.yml ps
$ docker compose ps traefik whoami
$ docker compose logs traefik --tail 100 | grep -i "acme\|cloudflare\|error"
```

Use [Troubleshooting](troubleshooting.md) for failure-specific checks.
