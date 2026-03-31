# Skill: Environment Health Check

> **Trigger**: `make env-check`, auto-invoked at Dev Agent Step 3, or "check environment"
> **Adapts to**: Kubernetes, Docker Compose, or custom — based on `workspace.yaml` formula.

---

## Step 1: Read Configuration

From `workspace.yaml`:

```yaml
environment:
  formula: kubernetes    # or docker-compose, custom
  commands:
    health: "..."       # custom health command (custom formula only)
```

From `workspace.yaml` services:
- `health_endpoint` per service (e.g., `/healthz`)
- `port` per service
- `namespace` per service (K8s)

---

## Step 2: Run Formula-Specific Checks

### Kubernetes Formula

#### Check 1: Cluster connectivity
```bash
kubectl cluster-info --request-timeout=5s
```
- **Pass**: Shows cluster URL
- **Fail**: "The connection to the server was refused" → cluster not running or kubeconfig wrong

#### Check 2: All pods health
```bash
kubectl get pods -A --no-headers
```

For each pod, check:
- Status = `Running` or `Completed` (both OK)
- READY = `x/x` (all containers ready)
- Restarts — if >5, it's flapping (warn)

```bash
# Find unhealthy pods specifically
kubectl get pods -A --no-headers | awk '{split($3,a,"/"); if(a[1]!=a[2] && $4!="Completed") print}'
```

#### Check 3: Service-specific pods
For each service in `workspace.yaml` that has a `namespace`:
```bash
kubectl get pods -n <namespace> -l app=<service-name> --no-headers
```

Verify at least one pod is Running and Ready.

#### Check 4: Health endpoints (if port-forward or ingress is available)
```bash
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://localhost:<port><health_endpoint>
```
- 200 → healthy
- Connection refused → port-forward not active or service not listening
- Non-200 → service running but unhealthy

### Docker Compose Formula

#### Check 1: Docker daemon
```bash
docker info --format '{{.ServerVersion}}' 2>/dev/null
```
- **Pass**: Shows version
- **Fail**: "Cannot connect to Docker daemon" → Docker not running

#### Check 2: Compose services
```bash
docker compose ps
```

For each service: Status should be "running" or "Up". "exited" or "restarting" = unhealthy.

#### Check 3: Health endpoints
Same as Kubernetes Check 4, but use the ports from docker-compose.yml.

### Custom Formula

Run the health command from `workspace.yaml`:
```bash
<environment.commands.health>
```

If no health command defined → report: "No health check configured. Add `environment.commands.health` to workspace.yaml."

---

## Step 3: Common Issue Diagnosis

When a check fails, suggest the fix:

| Symptom | Diagnosis | Suggested Fix |
|---------|-----------|---------------|
| Cluster unreachable | Kubeconfig wrong or cluster down | `kubectl config get-contexts` — verify context. If using Docker Desktop, enable K8s |
| Pod CrashLoopBackOff | Container starts then crashes | `kubectl logs <pod> -n <ns> --previous` — check startup error |
| Pod ImagePullBackOff | Can't pull container image | Check image name, registry auth: `kubectl describe pod <pod>` |
| Pod Pending | Not enough resources or node selector | `kubectl describe pod <pod>` — check Events section |
| Health endpoint refused | Port-forward not active | `kubectl port-forward svc/<service> <port>:<port> -n <ns>` |
| Health endpoint 503 | Service starting or dependency down | Wait 30s. If persists, check pod logs and downstream services |
| Docker compose exited | Missing env var or bad config | `docker compose logs <service>` — check startup error |
| Docker port conflict | Another process using the port | `lsof -i :<port>` — find and stop the conflicting process |
| High pod restarts (>5) | Flapping — OOM, config error, or dependency cycle | `kubectl describe pod <pod>` — check Events + resource limits |

---

## Step 4: Report

```markdown
## Environment Health: <timestamp>

### Infrastructure

| Component | Status | Details |
|-----------|--------|---------|
| Cluster | ✅ Connected | docker-desktop context |
| Pods | ✅ 12/12 healthy | All running and ready |

### Services

| Service | Pod Status | Health | Ready |
|---------|-----------|--------|-------|
| backend-api | 1/1 Running | 200 OK | ✅ |
| frontend | 1/1 Running | 200 OK | ✅ |
| auth-service | 1/1 Running | 200 OK | ✅ |
| postgres | 1/1 Running | — | ✅ |
| rabbitmq | 1/1 Running | — | ✅ |

### Issues Found

None — environment is ready.

### Issues Found (example with problems)

| Issue | Service | Severity | Fix |
|-------|---------|----------|-----|
| CrashLoopBackOff | worker | 🔴 | `kubectl logs worker-xyz -n backend --previous` |
| Port-forward down | backend-api | 🟡 | `kubectl port-forward svc/backend-api 8001:8001 -n backend` |
```

---

## Decision: Proceed or Fix?

| Result | Decision |
|--------|----------|
| All services healthy | Proceed with dev-agent workflow |
| Only non-critical service unhealthy (e.g., monitoring) | Proceed with warning |
| Any service involved in the ticket is unhealthy | Fix first — do NOT investigate on a broken env |
| Cluster/Docker not reachable | Fix first — nothing will work |
| Health endpoint down but pod is running | May proceed cautiously — service might be starting |

---

## Auto-Fix (When Safe)

Some issues can be fixed automatically:

| Issue | Auto-Fix | Safe? |
|-------|----------|-------|
| Port-forward not active | `kubectl port-forward svc/<svc> <port>:<port> -n <ns> &` | Yes — just networking |
| Docker compose service stopped | `docker compose up -d <service>` | Usually yes |
| Pod needs restart | `kubectl rollout restart deployment/<svc> -n <ns>` | Ask first — may disrupt |

Only auto-fix if the service isn't actively being used for development. Always report what was fixed.
