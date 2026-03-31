---
title: Portainer GitOps
---

# Deploy with Portainer GitOps

Use **Portainer GitOps** when you want Git to be the source of truth for deployments. Push a change, and Portainer redeploys the stack. For the service layout used here, read [Service Reference](services.md). For custom service files, see [Configuration](customization.md). For production DNS and TLS, see [VPN Deployment](production.md).

---

## Try It Now

Deploy your homelab using **Portainer GitOps**:

```bash
# 1. Start the infrastructure (if not already running)
$ docker compose --profile infra up -d
[+] Running 6/6
 ✔ Container homelab-traefik-1    Started
 ✔ Container homelab-sablier-1    Started
 ✔ Container homelab-rustfs-1     Started
 ...
```

```bash
# 2. Start Portainer
$ docker compose up -d portainer agent
[+] Running 2/2
 ✔ Container homelab-portainer-1  Started
 ✔ Container homelab-agent-1      Started
```

```bash
# 3. Wait for Portainer to be ready (30 seconds)
$ sleep 30

# 4. Verify Portainer is accessible
$ curl -k https://pods.traefik.me/api/status 2>/dev/null | jq '.Version'
"2.25.1"
```

Open `https://pods.traefik.me` in your browser and continue with the setup steps below.

!!! note
    On first access, **Portainer** will ask you to create an admin account. Use a strong password—this interface has full control over your Docker environment.

---

## What Is GitOps?

**GitOps** means your Git repository is the single source of truth for your infrastructure. Instead of manually editing files on the server, you:

1. Edit your `docker-compose.yml` locally
2. Push to GitHub
3. **Portainer** automatically pulls and redeploys

Benefits:
- **Version control**: Every change is tracked
- **Rollback**: Revert to any previous state
- **Collaboration**: Multiple people can contribute via pull requests
- **Audit trail**: See who changed what and when

---

## Step 1: Prepare Your Repository

Before **Portainer** can pull your stack, make sure your repository is ready:

### Required Files

Your repository must contain these files at minimum:

```
.
├── docker-compose.yml          # Main compose file (required)
├── .env.example                # Template for environment variables
├── services/
│   ├── secrets/              # Will be created by Portainer
│   └── .env-*              # Service-specific env files
└── traefik-config/             # Traefik dynamic configs
    └── traefik/
        ├── traefik.yml         # Static config
        └── dyn/
            └── *.yml         # Router configs
```

### Set Up Git Repository

If you haven't already:

```bash
# 1. Initialize Git (if not already done)
$ git init
Initialized empty Git repository in /home/user/homelab/.git/

# 2. Add your files
$ git add .

# 3. Commit
$ git commit -m "Initial homelab setup"
[main (root-commit) abc1234] Initial homelab setup
 42 files changed, 1234 insertions(+)
```

```bash
# 4. Add remote (replace with your repo URL)
$ git remote add origin https://github.com/yourusername/homelab.git

# 5. Push
$ git push -u origin main
Enumerating objects: 50, done.
Counting objects: 100% (50/50), done.
Delta compression using up to 8 threads
Compressing objects: 100% (42/42), done.
Writing objects: 100% (50/50), 12.34 KiB/s, done.
Total 50 (delta 5), reused 0 (delta 0), pack-reused 0
To https://github.com/yourusername/homelab.git
 * [new branch]      main -> main
```

---

## Step 2: Configure Portainer

### Access Portainer

1. Open `https://pods.${DOMAIN}` in your browser (e.g., `https://pods.traefik.me`)
2. Create your admin account on first visit
3. Select "Get Started" to use the local Docker environment

### Add Your Git Repository

1. In **Portainer**, go to **Stacks** → **Add Stack**
2. Select **Repository** as the build method
3. Configure the stack:

| Setting | Value | Description |
|---------|-------|-------------|
| **Name** | `homelab` | Stack identifier in Portainer |
| **Repository URL** | `https://github.com/yourusername/homelab` | Your Git repo |
| **Repository Reference** | `refs/heads/main` | Branch to track |
| **Compose path** | `docker-compose.yml` | Path to compose file |
| **Authentication** | (Optional) | For private repos, add credentials or deploy key |

!!! warning
    For private repositories, you must authenticate. Use either:
    - **Username/Password** (GitHub personal access token works as password)
    - **Deploy Key** (add the public key to your repo's deploy keys)

### Environment Variables

Add these required **environment variables**:

| Variable | Value | Required |
|----------|-------|----------|
| `DOMAIN` | `yourdomain.com` | Yes |
| `CF_API_EMAIL` | `you@yourdomain.com` | For production |

Click **"Add an environment variable"** for each:

```
DOMAIN=yourdomain.com
CF_API_EMAIL=you@yourdomain.com
```

### Enable GitOps Auto-Update

Check **"Enable GitOps"** and configure:

| Setting | Recommended Value | Description |
|---------|-------------------|-------------|
| **Mechanism** | `Webhook` | Push-based (instant) |
| **Fetch interval** | `5m` | Poll-based fallback |
| **Webhook URL** | (Auto-generated) | Copy this for GitHub |

Click **"Deploy the stack"**.

---

## Step 3: Configure GitHub Webhook


For instant redeploys when you push, add a webhook to your GitHub repository:


1. Go to your repository on GitHub
2. Navigate to **Settings** → **Webhooks** → **Add webhook**
3. Configure:
   - **Payload URL**: Paste the webhook URL from Portainer (e.g., `https://pods.yourdomain.com/api/stacks/webhook/abc123`)
   - **Content type**: `application/json`
   - **Secret**: (Leave blank, or set if you configured one)
   - **Events**: Select **Just the push event**
4. Click **Add webhook**

!!! note
    You can find the webhook URL in **Portainer** under your stack settings: Stacks → homelab → Editor → GitOps → Webhook URL.

---

## Step 4: Verify Deployment


### Check Stack Status

In **Portainer**:
1. Go to **Stacks** → **homelab**
2. You should see all services listed with green status indicators
3. Click on individual services to view logs

### Verify Services Are Accessible

```bash
# Test whoami endpoint
$ curl -k https://whoami.yourdomain.com
Hostname: homelab-whoami-1
IP: 172.20.0.2
```

```bash
# Test Traefik dashboard
$ curl -s -k https://traefik.yourdomain.com/api/version | jq
{
  "version": "3.0.0"
}
```

---

## Service-Specific Environment Variables


Each service may require additional **environment variables**. Set these in **Portainer** under your stack's **Environment variables** section:

### Required for All Services

| Variable | Service | Purpose | Example |
|----------|---------|---------|---------|
| `DOMAIN` | All | Base domain | `yourdomain.com` |
| `CF_API_EMAIL` | Traefik | Cloudflare account email | `you@domain.com` |

### Karakeep (Bookmark Manager)


| Variable | Purpose | Example |
|----------|---------|---------|
| `MEILI_MASTER_KEY` | Meilisearch authentication | `random-secret-key-32-chars-long` |
| `NEXTAUTH_SECRET` | NextAuth session encryption | `openssl rand -base64 32` |

**How to set:**
1. In **Portainer**, go to **Stacks** → **homelab** → **Editor**
2. Add to Environment variables:
   ```
   MEILI_MASTER_KEY=your-random-key-here
   NEXTAUTH_SECRET=your-nextauth-secret
   ```
3. Click **"Update the stack"**

### Immich (Photo Management)

| Variable | Purpose | Example |
|----------|---------|---------|
| `DB_USERNAME` | Immich database username | `immich` |
| `DB_PASSWORD` | Immich database password | `secure-password` |
| `DB_DATABASE_NAME` | Database name | `immich` |

**Note:** These are referenced in `services/.env-immich`:
```bash
DB_HOSTNAME=immich-postgres
DB_USERNAME=immich
DB_PASSWORD=immich
DB_DATABASE_NAME=immich
REDIS_HOSTNAME=redis
```

### Listmonk (Newsletters)

| Variable | Purpose | Example |
|----------|---------|---------|
| `LISTMONK_db__user` | Database username | `listmonk` |
| `LISTMONK_db__password` | Database password | `listmonk-pass` |
| `LISTMONK_db__database` | Database name | `listmonk` |

### RustFS (S3 Storage)

| Variable | Purpose | Example |
|----------|---------|---------|
| `RUSTFS_ACCESS_KEY` | S3 access key | `minioadmin` |
| `RUSTFS_SECRET_KEY` | S3 secret key | `minioadmin` |

### Paperless-ngx (Document Management)

| Variable | Purpose | Example |
|----------|---------|---------|
| `PAPERLESS_SECRET_KEY` | Django secret key | `openssl rand -hex 32` |
| `PAPERLESS_OCR_LANGUAGE` | OCR language | `eng` |

### NetAlertX (Network Scanner)

| Variable | Purpose | Example |
|----------|---------|---------|
| `NETALERTX_SCAN_SUBNETS` | Networks to scan | `192.168.1.0/24` |


---

## Managing Secrets


This stack uses a **file-based Docker secret** for Cloudflare. Keep that file under the stack checkout path (`services/secrets/cf_dns_api_token`).


| Secret File | Used By | How to provide it |
|-----------|---------|-------------------|
| `cf_dns_api_token` | Traefik | Create `services/secrets/cf_dns_api_token` in the stack working directory |

### Setting Secrets in Portainer


1. Open a shell on the Docker host running **Portainer**.
2. Create the secret file in the stack path:
   ```bash
   $ mkdir -p /data/compose/homelab/services/secrets
   $ echo -n 'your-cloudflare-token' > /data/compose/homelab/services/secrets/cf_dns_api_token
   ```
3. Redeploy the stack in **Portainer** (Stacks → homelab → Pull and redeploy).

!!! warning
    If your **Portainer** stack path is not `/data/compose/homelab`, check it with:
    `docker compose exec portainer ls -la /data/compose/`


---

## GitOps Workflow

Once configured, your workflow becomes:

```bash
# 1. Make changes locally
$ vim services/portainer.yml

# 2. Test locally (optional but recommended)
$ docker compose up -d portainer

# 3. Commit and push
$ git add .
$ git commit -m "Update Portainer resources"
[main 1a2b3c4] Update Portainer resources
 1 file changed, 4 insertions(+), 2 deletions(-)

$ git push origin main
Enumerating objects: 9, done.
Delta compression using up to 8 threads
Compressing objects: 100% (5/5), done.
Writing objects: 100% (9/9), 532 bytes | 532.00 KiB/s, done.
To https://github.com/yourusername/homelab.git
   abc1234..1a2b3c4  main -> main
```

**Portainer** automatically:
1. Receives webhook notification from GitHub
2. Pulls latest changes from your repo
3. Runs `docker compose up -d` with your environment variables
4. Updates the stack status in the UI

---

## Rollback

Made a mistake? Roll back to a previous version:

1. In **Portainer**, go to **Stacks** → **homelab**
2. Click **"Rollback"** button
3. Select the previous revision from the dropdown
4. Click **"Rollback"**

Or via Git:

```bash
# Revert last commit
$ git revert HEAD

# Push (triggers Portainer redeploy)
$ git push origin main
```

---

## Troubleshooting

### Stack Shows "Failed" Status

**Check:** Repository is accessible
```bash
$ curl -I https://github.com/yourusername/homelab
HTTP/2 200
```

**Check:** Webhook is configured correctly
In **Portainer**: Stacks → homelab → Editor → GitOps. Verify webhook URL matches GitHub settings.

**Check:** Portainer logs
```bash
$ docker compose logs portainer --tail 100
portainer  | 2026/03/03 12:00PM INF github.com/portainer/portainer/api/cmd/portainer/main.go:501 > starting Portainer version=2.25.1
```

### Services Not Updating

**Check:** Environment variables are set
In **Portainer**: Stacks → homelab → Editor. Verify all required variables are listed.

**Check:** Secrets exist
```bash
$ docker compose exec portainer ls -la /data/compose/homelab/services/secrets/
total 8
drwxr-xr-x 2 root root 4096 Mar  3 12:00 .
drwxr-xr-x 3 root root 4096 Mar  3 12:00 ..
-rw------- 1 root root   40 Mar  3 12:00 cf_dns_api_token
```

**Force redeploy:**
In **Portainer**: Stacks → homelab → Click **"Pull and redeploy"**

### GitHub Webhook Not Working

**Check:** Webhook delivered successfully
In GitHub: Repository → Settings → Webhooks → Click webhook → Recent Deliveries. Look for green checkmarks.

**Check:** Portainer accessible from GitHub
```bash
$ curl -X POST https://pods.yourdomain.com/api/stacks/webhook/YOUR_WEBHOOK_ID
{"message":"Invalid stack"}  # This is expected for empty POST
```

If you get connection errors, ensure your **Portainer** instance is publicly accessible.

### Environment Variables Not Applied

**Check:** Variables are saved in Portainer
In **Portainer**: Stacks → homelab → Editor → Environment variables section.

**Check:** Variable names match exactly
Case-sensitive: `DOMAIN` ≠ `domain`

**Force update:**
Make a trivial commit to trigger redeploy:
```bash
$ git commit --allow-empty -m "Trigger redeploy"
$ git push
```

---

## Advanced: Multiple Environments

Deploy the same stack to different environments (dev/staging/prod):

1. Create separate stacks in **Portainer**:
   - `homelab-dev` → tracks `develop` branch
   - `homelab-prod` → tracks `main` branch

2. Use different environment variables per stack:
   - `homelab-dev`: `DOMAIN=dev.yourdomain.com`
   - `homelab-prod`: `DOMAIN=yourdomain.com`

3. Configure different webhooks for each stack

---

## Advanced: Private Submodules

If your repo includes private submodules:

1. In **Portainer**, when adding the stack:
   - Check **"Repository authentication"**
   - Enter SSH key or username/password
2. Ensure the credentials have access to submodules
3. Use relative URLs in `.gitmodules`:
   ```
   [submodule "config"]
       path = config
       url = ../private-config.git
   ```

---

## Best Practices

1. **Never commit secrets**: Add `services/secrets/` to `.gitignore`
2. **Use `.env.example`**: Commit a template, keep real values in **Portainer**
3. **Test locally first**: Run `docker compose config` before pushing
4. **Enable webhook**: Instant deploys beat polling every 5 minutes
5. **Monitor deployments**: Check **Portainer** notifications for failures
6. **Version pin images**: Use `image: traefik:3.0` not `image: traefik:latest`

---

## Summary

| Task | Time | Command/UI Path |
|------|------|-----------------|
| Start infrastructure | 2 min | `docker compose --profile infra up -d` |
| Configure GitOps stack | 5 min | Portainer → Stacks → Add Stack → Repository |
| Add GitHub webhook | 3 min | GitHub → Settings → Webhooks |
| Verify deployment | 2 min | `curl -k https://whoami.yourdomain.com` |
| Deploy changes | 1 min | `git push origin main` |

**Total setup time: ~15 minutes**
**Time per deploy: ~1 minute (just push to Git)**
