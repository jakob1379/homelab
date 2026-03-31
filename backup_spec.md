# Docker Volume Backup Specification

## Overview

A Python-based backup orchestrator using restic for incremental backups of Docker volumes. Containers are grouped for coordinated stop/start, with full restic argument customization.

## Architecture

### Service Structure

```
backup/
├── Dockerfile              # Python + restic
├── pyproject.toml         # Dependencies
├── config/
│   └── backup.toml        # Global configuration
└── src/
    ├── main.py            # Scheduler + orchestration
    ├── config.py          # TOML parsing
    ├── docker_client.py   # Container discovery & lifecycle
    └── backup_engine.py   # Restic execution
```

### Runtime Behavior

1. Discover containers with `backup.enabled=true`
2. Group by `backup.group` label
3. For each group (sequential processing):
   - Stop containers with `backup.stop=true`
   - Backup all volumes using restic with custom args
   - Start containers
   - Continue to next group (failure isolation)

## Container Labels

| Label | Required | Default | Description |
|-------|----------|---------|-------------|
| `backup.enabled` | Yes | - | Opt-in to backup |
| `backup.group` | Yes | - | Group name for coordinated stop/start |
| `backup.stop` | No | `true` | Stop container during backup |
| `backup.args` | No | - | Custom restic backup arguments |

### Example Usage

```yaml
# Database - need consistency, exclude WAL files
labels:
  - backup.enabled=true
  - backup.group=postgres
  - backup.args="--exclude=pg_wal --one-file-system"

# Media server - exclude cache
labels:
  - backup.enabled=true
  - backup.group=jellyfin
  - backup.args="--exclude=/config/transcodes --exclude=*.tmp"

# Always-on monitoring - don't stop
labels:
  - backup.enabled=true
  - backup.group=monitoring
  - backup.stop=false
```

## Configuration Format (TOML)

```toml
[backup]
repository = "s3:http://rustfs:9000/backups"
password_file = "/run/secrets/restic_password"
# Optional AWS credentials for S3
aws_access_key_id_file = "/run/secrets/aws_access_key"
aws_secret_access_key_file = "/run/secrets/aws_secret_key"

[schedule]
enabled = true
frequency = "daily"        # daily, hourly, weekly
preferred_time = "02:00:00"

[prune]
enabled = true
keep_hourly = 48
keep_daily = 14
keep_weekly = 4
keep_monthly = 12
keep_yearly = 10

[check]
enabled = true
frequency = "weekly"       # Run restic check every N days/weeks

[restic]
global_args = "--verbose"  # Applied to all restic commands

[timeouts]
stop_grace_period = 30     # Seconds to wait for graceful stop
backup_operation = 3600    # Max backup time (1 hour)
```

## Docker Compose Service

```yaml
services:
  backup:
    profiles: [infra]
    build: ./backup
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./backup/config:/config:ro
    environment:
      - CONFIG_PATH=/config/backup.toml
    secrets:
      - restic_password
      - aws_access_key
      - aws_secret_key
    restart: unless-stopped
```

## Restic Command Construction

For each container in a group, the backup command is:

```bash
restic backup <global_args> <backup.args> /volume-path
```

**Example:**
- Global args: `--verbose`
- Container args: `--exclude=*.log --one-file-system`
- Result: `restic backup --verbose --exclude=*.log --one-file-system /usr/src/app/upload`

## Execution Flow

```
1. Scheduler triggers (Python sched module)
   |
   |
2. Discover: docker ps --filter label=backup.enabled=true
   |
   |
3. Group containers by backup.group label
   |
   |
4. For each group (sequential):
   |
   |-- 4a. Stop all containers with backup.stop=true
   |        (respect stop_grace_period timeout)
   |
   |-- 4b. For each stopped container:
   |        - Create ephemeral container with --volumes-from
   |        - Execute: restic backup <args> /volume
   |        - Destroy ephemeral container
   |
   |-- 4c. Start all stopped containers
   |
   |-- 4d. Continue to next group (regardless of success/failure)
   |
   |
5. Maintenance tasks (if enabled):
   - restic forget --prune (based on retention policy)
   - restic check (based on check frequency)
```

## Failure Handling

- **Stop failure**: Log error, skip group, continue
- **Backup failure**: Log error, attempt restart, continue
- **Start failure**: Log error, continue
- **Isolation**: One group's failure does not affect others

## Logging

- JSON format structured logging
- Levels: DEBUG, INFO, WARNING, ERROR
- Output to stdout (Docker handles collection)
