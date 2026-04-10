## Summary

This PR updates the homelab Docker Compose setup with improvements to service configuration, dependency management, and domain standardization using `traefik.me` as the default domain. It maintains the single-command startup solution for development with proper dependency ordering.

### Changes

1. **Docker Compose Architecture**
   - Uses Docker Compose with `depends_on` and healthcheck conditions for proper startup ordering
   - Traefik configured with Docker provider in `traefik.yml`
   - Root `docker-compose.yml` includes all stacks with clear separation
   - Healthchecks implemented for key services (Traefik, PostgreSQL, RustFS)
   - Development secret files with placeholder values

2. **Clean Separation of Concerns**
   - Organized services into logical stack files in `services/` directory:
     - `networking.yml`: Traefik, Sablier, Forward Auth, Whoami, AdGuard, NetAlertX
     - `postgres.yml`: PostgreSQL
     - `rustfs.yml`: RustFS (S3-compatible storage)
     - `monitoring.yml`: Shepherd, Dozzle
     - `tools.yml`: IT Tools, CloudBeaver, BentoPDF
      - Application-specific stacks: `listmonk.yml`, `hoarder.yml`, `pods.yml`
   - Root `docker-compose.yml` includes all stacks with shared networks and volumes
   - Simplified service management: start all with `docker compose up` or specific stacks with `docker compose up stackname`

3. **Domain Standardization & Configurability**
   - Uses `${DOMAIN:-traefik.me}` domain configuration across all files
   - Default Traefik rule uses `${DOMAIN:-traefik.me}`
   - `DOMAIN` environment variable supported for Traefik and traefik-forward-auth services
   - All dyn configs (`config/traefik/dyn/*.yml`) use `${DOMAIN:-traefik.me}`

4. **Declarative Network Setup**
   - `traefik_public` network is defined declaratively in Docker Compose files
   - No manual `docker network create` required
   - Network created automatically when basestack is deployed

5. **Health Checks & Reliability**
   - Added Docker healthchecks to PostgreSQL, Traefik, and RustFS
   - Ensures services are ready before dependent apps start
   - `depends_on` conditions ensure correct startup order: basestack → apps

6. **Single-Command Startup Solution**
   - `scripts/start-dev.sh` provides Docker Compose-based deployment
   - Supports `--basestack-only` and `--apps-only` modes
   - Creates dummy Docker secret files if missing for development
   - Waits for Traefik readiness before deploying apps

7. **Makefile Integration**
   - `make dev` - Full development environment with Docker Compose
   - `make dev-basestack` - Only basestack services
   - `make dev-apps` - Only app stacks
   - `make clean` - Remove all Docker Compose stacks (with confirmation)

8. **Documentation & Development Setup**
   - Clean Docker Compose stack file organization
   - Placeholder environment files for services
   - Traefik configured for Docker provider

9. **GitHub Workflow & CI**
   - `.github/workflows/test-docker-compose.yml` provides automated validation
   - Workflow validates Docker Compose configuration with `docker compose config`
   - Includes syntax checking for startup scripts
   - Quick start test to verify basic service startup
   - Status badge in README for workflow results

### Benefits
- **Proper startup ordering**: Services start in correct order with `depends_on` and healthchecks
- **Simplified management**: Docker Compose provides `depends_on`, easier network management
- **Quick local testing**: No custom domain or Cloudflare DNS required
- **Configurable domain**: Single `DOMAIN` variable controls all hostnames
- **Automatic setup**: Single command deploys entire stack with proper dependency ordering
- **Production ready**: Easy switch to custom domain with Docker Compose
- **Better reliability**: Health checks and dependency ordering
- **Declarative infrastructure**: Network defined in code, not manual steps

### Testing
- All Docker Compose configuration files pass syntax validation (`docker compose config`)
- Script passes `bash -n` syntax checking
- Domain changes are consistent across codebase
- Variable substitution tested in Docker Compose files
- Basic container startup tested locally (Traefik starts successfully)
- GitHub Actions workflow validates configuration on each push/PR
- Quick start test verifies basic service startup functionality
