---
title: Deployment
---

# Deploy Through Portainer

Use this guide for the full deployment path in this repo. Start the separate `docker-compose.pods.yml` bootstrap stack, open **Portainer** on port `9443`, then let **Portainer** deploy **Traefik**, **AdGuard**, and the rest of the main homelab stack from Git. **Dockhand** is also available on port `3000` during bootstrap for local management. For service layout, read [Service Reference](services.md). For routing and profiles, read [Architecture](architecture.md). For custom stacks, read [Configuration](customization.md). For failures, use [Troubleshooting](troubleshooting.md).

---

## Try It Now

This is the shortest working path from a fresh clone to a fully deployed stack:

```bash title="Fresh-host deployment path"
# 1. Clone and prepare the local env files
$ git clone https://github.com/jakob1379/homelab.git && cd homelab
Cloning into 'homelab'...
done.

$ ./setup-dev.sh
[INFO] Setting up the homelab development environment...
[INFO] setup-dev.sh leaves password-style credentials alone and only generates app keys
[INFO] Setup complete!

# 2. Set your real deployment domain and required secrets
$ cat > .env <<'EOF'
DOMAIN=lab.example.com
ACME_EMAIL=you@example.com
CF_DNS_API_TOKEN=your_cf_api_token
DOCKHAND_DATA_DIR=/opt/dockhand
EOF

# 3. Bootstrap only Portainer + Dockhand
$ docker compose -f docker-compose.pods.yml up -d
[+] Running 2/2
  ✔ Container homelab-pods-portainer-1  Started
  ✔ Container homelab-pods-dockhand-1   Started
```

```bash title="Verify the Portainer bootstrap endpoint"
# 4. Verify the bootstrap control plane
$ curl -sk https://localhost:9443/api/status | jq '.Version'
"2.25.1"
```

Open `https://localhost:9443`, create the admin user, then create a **Repository** stack that points back to this repo. Dockhand is available on `http://localhost:3000` for bootstrap access. After Portainer finishes the full deploy, verify the routed stack:

Dockhand now uses a matching host path for its data directory by default. Keep `DOCKHAND_DATA_DIR` on a real host path such as `/opt/dockhand` so Git-managed stacks with relative bind mounts resolve correctly when Docker creates the target containers.

```bash title="Verify the routed stack after the full deploy"
# 5. Verify the full stack after Portainer deploys it
$ curl -k https://whoami.lab.example.com
Hostname: homelab-whoami-1
IP: 172.20.0.2
```

!!! note
    During bootstrap, **Traefik** is not running yet, so `https://pods.${DOMAIN}` does not exist. Use `https://localhost:9443` or `https://<server-ip>:9443` until Portainer deploys the full stack.

---

## Why The Bootstrap Uses A Separate Compose Stack

The separate `docker-compose.pods.yml` stack provides a small control plane:

1. Start **Portainer** and **Dockhand** with `docker compose -f docker-compose.pods.yml up -d`.
2. Use **Portainer** to deploy `docker-compose.yml` as the real homelab stack.
3. Let that stack create **Traefik**, **AdGuard**, **RustFS**, and the app stacks, then route traffic to the still-separate `pods` and `dockhand` containers.

This matters for two reasons:

- You do not need **Traefik** running before you can manage the host.
- The deployment story matches the repo: **Portainer** becomes the system entrypoint, not a service you must manually route first.

---

## Step 1: Prepare The Repo

You need the following before the full deploy works:

- A root `.env` with `DOMAIN`, `ACME_EMAIL`, `CF_DNS_API_TOKEN`, and the app secrets required by the profiles you plan to run
- `DOCKHAND_DATA_DIR` set to a real host path such as `/opt/dockhand` if you want Dockhand Git stacks to support relative bind mounts
- Any shell or direnv-provided values you intentionally keep out of `.env`, such as `SPEEDTEST_APP_KEY`

```bash title="Create the root deployment files"
# Create the main environment file
$ cat > .env <<'EOF'
DOMAIN=lab.example.com
ACME_EMAIL=you@example.com
CF_DNS_API_TOKEN=your_cf_api_token
DOCKHAND_DATA_DIR=/opt/dockhand
EOF
```

If you want media automation, add the ProtonVPN credentials before deployment:

```bash title="Optional ProtonVPN credentials"
# Optional: enable Gluetun + Arr download traffic later
$ cat >> .env <<'EOF'
OPENVPN_USER=your_proton_openvpn_username
OPENVPN_PASSWORD=your_proton_openvpn_password
VPN_SERVER_COUNTRIES=Netherlands
EOF
```

If you skip the VPN credentials, the media stack will boot later with an explicit error:

```bash title="Expected Gluetun error when VPN credentials are missing"
$ docker compose logs gluetun --tail 20
gluetun  | ERROR VPN settings: OPENVPN_USER is not set
```

---

## Step 2: Bootstrap Portainer

The `docker-compose.pods.yml` stack exists specifically for the deployment control plane.

```bash title="Start the bootstrap control plane"
# Start only the Portainer bootstrap services
$ docker compose -f docker-compose.pods.yml up -d
[+] Running 2/2
  ✔ Container homelab-pods-portainer-1  Started
  ✔ Container homelab-pods-dockhand-1   Started
```

```bash title="Confirm Portainer is answering on port 9443"
# Confirm Portainer is answering on the direct host port
$ curl -sk https://localhost:9443/api/status | jq
{
  "Version": "2.25.1",
  "Edition": "CE"
}
```

Open `https://localhost:9443` and complete the first-login flow:

1. Create the **Portainer** admin user.
2. Add the local Docker environment that connects to the host socket.
3. Go to **Stacks** and select **Add stack**.
4. Choose **Repository** as the deployment method.

---

## Step 3: Let Portainer Deploy The Homelab

Use the same repository as the source of truth.

Recommended stack settings:

| Setting | Value |
|---------|-------|
| **Name** | `homelab` |
| **Build method** | `Repository` |
| **Repository URL** | `https://github.com/yourusername/homelab` |
| **Repository reference** | `refs/heads/main` |
| **Compose path** | `docker-compose.yml` |
| **GitOps update mechanism** | `Webhook` |
| **Poll fallback** | `5m` |

Add these **environment variables** in the stack editor if you deploy the full main stack:

```text title="Portainer stack variables"
DOMAIN=lab.example.com
ACME_EMAIL=you@example.com
CF_DNS_API_TOKEN=your_cf_api_token
IMMICH_DB_PASSWORD=...
LISTMONK_db__password=...
PAPERLESS_DBPASS=...
PAPERLESS_SECRET_KEY=...
NEXTAUTH_SECRET=...
MEILI_MASTER_KEY=...
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

### Important: Portainer must receive every required variable for the profiles you deploy

This repo now fails fast with `${VAR:?message}` checks. When Portainer deploys from Git, make sure the stack environment includes at least:

- `DOMAIN`
- `ACME_EMAIL`
- `CF_DNS_API_TOKEN`
- `IMMICH_DB_PASSWORD`
- `LISTMONK_db__password`
- `PAPERLESS_DBPASS`
- `PAPERLESS_SECRET_KEY`
- `NEXTAUTH_SECRET`
- `MEILI_MASTER_KEY`
- `RUSTFS_ACCESS_KEY`
- `RUSTFS_SECRET_KEY`
- `SPEEDTEST_APP_KEY`

!!! warning
    If one of the required variables is missing from the Portainer stack environment, Compose rendering fails before the stack deploy completes.

### What happens on the first full deploy

Portainer deploys the repo as the real stack. That deploy includes:

- **Traefik**
- **Sablier**
- **AdGuard**
- **RustFS**
- app stacks such as **Immich** and **Paperless**

The bootstrap `docker-compose.pods.yml` stack keeps running separately. Once the main stack brings up **Traefik**, the `pods.${DOMAIN}` and `docker.${DOMAIN}` routes point at those bootstrap containers over the shared `traefik_public` network.

---

## Step 4: Configure DNS And TLS For Production

This repo uses **Cloudflare DNS-01** for certificate issuance and **VPN DNS** for client resolution.

!!! info "Production Checklist"
    Before you treat the stack as production-ready, make sure you:

    - bootstrap the host with `docker compose -f docker-compose.pods.yml up -d`
    - deploy the full homelab through **Portainer**
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

### NetBird DNS

In **NetBird**:

1. Add the **AdGuard** instance as the DNS server for the peer groups that should use the homelab.
2. Confirm clients in those groups receive the NetBird DNS settings.

If you skip this step, certificate issuance may still succeed through **Cloudflare**, but clients will not resolve your app hostnames to the VPN IP.

---

## Step 5: Verify The Deployed Stack

After Portainer finishes the full deploy, confirm routing, DNS, and TLS.

```bash title="Check the Traefik API after deployment"
# Check that the routed entrypoint is alive
$ curl -sk https://traefik.lab.example.com/api/version | jq
{
  "version": "3.6.9"
}
```

```bash title="Check DNS from a VPN-connected client"
# Check DNS from a VPN-connected client
$ nslookup whoami.lab.example.com
Name: whoami.lab.example.com
Address: 100.90.12.34
```

```bash title="Check the routed whoami service"
# Check the routed whoami service
$ curl -k https://whoami.lab.example.com
Hostname: homelab-whoami-1
IP: 172.20.0.2
```

```bash title="Confirm the issued certificate"
# Check certificate issuer
$ curl -vkI https://whoami.lab.example.com 2>&1 | grep -E "(subject:|issuer:)"
*  subject: CN=whoami.lab.example.com
*  issuer: C=US; O=Let's Encrypt; CN=R3
```

---

## Common Confusion Points

### `https://pods.${DOMAIN}` does not work right after bootstrap

That is expected. The `docker-compose.pods.yml` bootstrap stack only publishes **Portainer** directly on `9443` and **Dockhand** on `3000`. The routed `pods.${DOMAIN}` hostname appears only after the full stack deploy creates **Traefik**.

### `docker compose -f docker-compose.pods.yml up -d` starts only two containers

That is correct. The bootstrap stack is intentionally small:

- `portainer`
- `dockhand`

Everything else is created by the Portainer-managed stack.

### The bootstrap stack stays separate after the full deploy

That is intentional. Bootstrap gets you into the UI. The first full deploy creates the Git-managed main stack, while **Portainer** and **Dockhand** continue running from `docker-compose.pods.yml` as their own control-plane stack.

---

## Troubleshooting

### Portainer bootstrap is up, but Dockhand is missing

Confirm both bootstrap services are running:

```bash title="Confirm the bootstrap services exist"
$ docker compose -f docker-compose.pods.yml ps
NAME                 IMAGE                       STATUS
homelab-pods-portainer-1  portainer/portainer-ce:2.25.1 Up
homelab-pods-dockhand-1   fnsys/dockhand:latest       Up
```

If `dockhand` is missing, restart the bootstrap stack:

```bash title="Restart the bootstrap stack"
$ docker compose -f docker-compose.pods.yml up -d
[+] Running 2/2
  ✔ Container homelab-pods-portainer-1  Started
  ✔ Container homelab-pods-dockhand-1   Started
```

### The full deploy comes up, but Traefik cannot issue certificates

The most common cause is a missing or wrong token in the Portainer stack environment.

Check the stack variables in Portainer and confirm `CF_DNS_API_TOKEN` is set.

### Certificates are not issued

Check **Traefik** logs after the full deploy:

```bash title="Check Traefik ACME and Cloudflare errors"
$ docker compose logs traefik --tail 100 | grep -i "acme\\|cloudflare\\|error"
traefik  | error renewing certificate for domain lab.example.com
```

Most common causes:
- wrong token value in `CF_DNS_API_TOKEN`
- missing `Zone:Read` or `DNS:Edit` permissions
- missing `ACME_EMAIL`
- wrong `DOMAIN` value in `.env` or Portainer stack variables

### DNS resolves the wrong IP

From a VPN-connected client:

```bash title="Check whether DNS resolves the VPN IP"
$ nslookup whoami.lab.example.com
Name: whoami.lab.example.com
Address: 203.0.113.10
```

That result is wrong for the VPN-only model. Fix the DNS path:

- confirm NetBird assigns **AdGuard** as the client DNS server
- confirm **AdGuard** has the wildcard rewrite for `*.lab.example.com`
- confirm the wildcard points to the homelab host's VPN IP, not a public IP

---

## Recommended Deployment Cycle

Use this cycle for ongoing changes:

1. Edit and commit in Git.
2. Push to the tracked branch.
3. Let **Portainer GitOps** redeploy the stack.
4. Verify a routed endpoint such as `https://whoami.${DOMAIN}`.

For one-off validation before pushing, run:

```bash title="Validate the compose configuration before pushing"
$ docker compose config > /dev/null && echo "config ok"
config ok
```

That keeps the docs aligned with the repo: **Portainer** and **Dockhand** are the bootstrap control plane, and the documented deployment path remains Portainer-managed from Git.
