# Queue-Driven Sleep Pattern

This repo no longer uses the queue-driven sleep pattern for Immich.

The current Immich stack runs fully on:

- `immich-server` is exposed directly through Traefik Docker labels in `services/immich.yml`
- `immich-microservices` and `immich-machine-learning` stay running with the rest of the stack
- there is no `immich-queue-monitor` service and no Immich-specific Sablier worker group

Use this document as a design note only if you choose to reintroduce queue-driven worker wake in the future. The active source of truth for Immich is now:

- `services/immich.yml`
- `docs/services.md`
