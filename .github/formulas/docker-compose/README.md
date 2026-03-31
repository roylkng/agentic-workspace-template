# Docker Compose Formula

> Adapts workspace commands for Docker Compose development environments.
> Works with: Docker Compose v2, Podman Compose.

## Prerequisites

- Docker Engine installed and running
- Docker Compose v2 (`docker compose version`)

## Command Mapping

| Workspace Command | Docker Compose Implementation |
|-------------------|------------------------------|
| `make env-check` | `docker compose ps --format json`, check State=running |
| `make deploy-<svc>` | `docker compose up -d <svc> --build` |
| `make logs <svc>` | `docker compose logs <svc> --tail=100` |
| `make restart <svc>` | `docker compose restart <svc>` |
| `make stop` | `docker compose down` |
| `make start` | `docker compose up -d` |

## Health Check Implementation

```bash
#!/bin/bash
# Check Docker is running
docker info >/dev/null 2>&1 || { echo "ERROR: Docker not running"; exit 1; }

# Check compose project
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
docker compose -f "$COMPOSE_FILE" ps --format json | python3 -c "
import sys, json
services = json.loads(sys.stdin.read())
if isinstance(services, dict):
    services = [services]
unhealthy = [s for s in services if s.get('State') != 'running']
if unhealthy:
    print(f'WARNING: {len(unhealthy)} unhealthy service(s)')
    for s in unhealthy:
        print(f'  - {s[\"Name\"]}: {s[\"State\"]}')
    sys.exit(1)
print(f'OK: {len(services)} services running')
"
```

## Service Discovery

Services map to compose service names. Ports from compose file expose section.

```yaml
# docker-compose.yml
services:
  backend-api:
    build: ./services/backend-api
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/healthz"]
```

## Common Patterns

### All-in-one compose
Single `docker-compose.yml` at workspace root that builds all services.

### Per-service compose
Each service has its own compose file; workspace-level compose orchestrates.

### Infra compose + local services
Infrastructure (DB, cache, queue) in compose; services run natively for faster iteration.
