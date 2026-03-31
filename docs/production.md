---
title: VPN Deployment
---

# VPN-Only Deployment With Let's Encrypt

Use this guide for the intended production model of this project. It covers VPN-only access, Cloudflare DNS-01 validation, and the DNS path that sends clients to Traefik. For service layout and routing, read [Architecture](architecture.md) and [Service Reference](services.md). For service changes, use [Configuration](customization.md). For failures, see [Troubleshooting](troubleshooting.md).

- services are reachable on your VPN network (for example NetBird)
- services are not published to the public internet
- Cloudflare is used for DNS-01 validation so Traefik can prove domain ownership to Let's Encrypt
- NetBird DNS points clients to AdGuard, and AdGuard wildcard records route all app hostnames to Traefik

## Try It Now

```bash
# 1. Set your domain (example: lab.example.com)
$ export DOMAIN=lab.example.com
$ echo "DOMAIN=lab.example.com" > .env
$ echo "CF_API_EMAIL=you@example.com" >> .env

# 2. Add Cloudflare API token secret
$ echo -n 'your_cf_api_token' > services/secrets/cf_dns_api_token

# 3. Configure NetBird DNS to use AdGuard
#    (set NetBird DNS nameserver to your AdGuard VPN IP)

# 4. Deploy
$ docker compose up -d
[+] Running ...
 ✔ Container homelab-traefik-1  Started
 ✔ Container homelab-whoami-1   Started
 ...

# 5. Verify DNS from a VPN-connected client
$ nslookup whoami.lab.example.com
Name: whoami.lab.example.com
Address: 100.90.12.34

# 6. Verify certificate
$ curl -vkI https://whoami.lab.example.com 2>&1 | grep -E "(subject:|issuer:)"
*  subject: CN=whoami.lab.example.com
*  issuer: C=US; O=Let's Encrypt; CN=R3
```

## Architecture Intent

In this model, DNS and TLS have separate responsibilities:

- **Cloudflare DNS zone**: used by Traefik for `_acme-challenge` TXT records (DNS-01)
- **NetBird DNS**: distributes DNS resolver settings to VPN clients
- **AdGuard DNS**: resolves wildcard app hostnames to your Traefik VPN IP

Resolution flow:

`VPN client -> NetBird DNS config -> AdGuard -> Traefik`

Important:

- You do not need public `A`/`AAAA` records for app endpoints to issue certificates with DNS-01.
- You do need clients to resolve service hostnames to your server's VPN IP.

## Prerequisites

- A registered domain managed in Cloudflare
- Cloudflare API token with:
  - `Zone:Read`
  - `DNS:Edit`
- NetBird network set up and your homelab host joined
- VPN clients joined to NetBird and using NetBird-managed DNS
- AdGuard reachable on the VPN network

## Setup Steps

### Step 1: Set Domain and Cloudflare Email

```bash
$ echo "DOMAIN=lab.example.com" > .env
$ echo "CF_API_EMAIL=you@example.com" >> .env
```

### Step 2: Add Cloudflare API Token Secret

```bash
$ echo -n 'your_cf_api_token' > services/secrets/cf_dns_api_token
```

```bash
# Verify there is no trailing newline
$ cat -A services/secrets/cf_dns_api_token
your_cf_api_token
```

### Step 3: Configure NetBird DNS and AdGuard Wildcard

In NetBird DNS management:

1. Add your AdGuard instance as a DNS nameserver for the peer groups that should access the homelab.
2. Ensure clients in those groups use that DNS settings.

In AdGuard DNS rewrites (or equivalent local DNS records), add wildcard records to your server VPN IP:

```text
A  *.lab.example.com  100.90.12.34
A  lab.example.com    100.90.12.34
```

Use your real server VPN IP from NetBird.

### Step 4: Deploy the Stack

```bash
$ docker compose up -d
[+] Running ...
 ✔ Container homelab-traefik-1  Started
 ✔ Container homelab-portainer-1 Started
 ...
```

### Step 5: Verify From a VPN Client

```bash
$ nslookup whoami.lab.example.com
Name: whoami.lab.example.com
Address: 100.90.12.34
```

```bash
# Optional: query AdGuard directly by IP
$ nslookup whoami.lab.example.com 100.90.12.53
Server:  100.90.12.53
Address: 100.90.12.53#53

Name: whoami.lab.example.com
Address: 100.90.12.34
```

```bash
$ curl -k https://whoami.lab.example.com
Hostname: homelab-whoami-1
```

## Security Posture (VPN-Only)

- Do not publish your homelab services on WAN DNS.
- Restrict inbound firewall rules so app access comes from VPN/internal networks only.
- Keep admin UIs behind `admin-only@file` middleware where applicable.

This project already supports internal network allowlists in `traefik-config/traefik/dyn/common.yml`.

## Troubleshooting

### Certificate Not Issued

```bash
$ docker compose logs traefik --tail 100 | grep -i "acme\|cloudflare\|error"
```

Most common causes:

- invalid Cloudflare token permissions
- wrong token value in `services/secrets/cf_dns_api_token`
- wrong `DOMAIN` value in `.env`

### DNS Resolves Public IP Instead of VPN IP

From the client:

```bash
$ nslookup whoami.lab.example.com
```

If the answer is not the VPN IP:

- check NetBird DNS nameserver assignment for the client peer group
- confirm AdGuard wildcard rewrite points to the homelab VPN IP
- confirm client is connected to NetBird and uses NetBird DNS settings

### Wildcard Subdomains Do Not Resolve

```bash
$ nslookup test.lab.example.com
```

If wildcard lookups fail:

- verify `*.lab.example.com` exists in AdGuard DNS rewrites
- verify AdGuard is reachable from client VPN network
- verify NetBird DNS points the client to AdGuard

### Let's Encrypt Rate Limit

Use staging while iterating:

```yaml
# services/networking.yml
services:
  traefik:
    environment:
      - TRAEFIK_CERTIFICATESRESOLVERS_CFRESOLVER_ACME_CASERVER=https://acme-staging-v02.api.letsencrypt.org/directory
```

```bash
$ docker compose up -d traefik
```

Remove the staging override after validation.

## Service URLs

With `DOMAIN=lab.example.com`:

- `https://traefik.lab.example.com`
- `https://pods.lab.example.com`
- `https://photos.lab.example.com`
- `https://paperless.lab.example.com`
- `https://jellyfin.lab.example.com`
- `https://requests.lab.example.com`

All of these should resolve to your server VPN IP through your VPN DNS setup.
