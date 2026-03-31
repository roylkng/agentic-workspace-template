# Kubernetes Formula

> Adapts workspace commands for Kubernetes-based development environments.
> Works with: Docker Desktop, Minikube, Kind, Rancher Desktop, EKS, GKE, AKS.

## Prerequisites

- `kubectl` CLI installed and configured
- Active cluster connection (`kubectl cluster-info` succeeds)
- Helm 3.x (if using Helm charts)
- Skaffold (optional, for build-deploy automation)

## Command Mapping

| Workspace Command | Kubernetes Implementation |
|-------------------|--------------------------|
| `make env-check` | `kubectl get pods -A`, check READY status |
| `make deploy-<svc>` | `skaffold deploy -p <profile>` or `helm upgrade` |
| `make logs <svc>` | `kubectl logs -n <ns> -l app=<svc> --tail=100` |
| `make restart <svc>` | `kubectl rollout restart deployment/<svc> -n <ns>` |
| `make port-forward <svc>` | `kubectl port-forward -n <ns> svc/<svc> <local>:<remote>` |

## Health Check Implementation

```bash
#!/bin/bash
# Check cluster connectivity
kubectl cluster-info --request-timeout=5s || { echo "ERROR: Cannot reach cluster"; exit 1; }

# Check for non-running pods (exclude completed jobs)
UNHEALTHY=$(kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l)
if [ "$UNHEALTHY" -gt 0 ]; then
    echo "WARNING: $UNHEALTHY unhealthy pod(s) detected"
    kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
fi

# Check specific services from workspace.yaml
# (Makefile iterates services and checks each)
```

## Service Discovery

For each service in `workspace.yaml` with a `namespace` field:

```bash
kubectl get deployment/<service-name> -n <namespace> -o jsonpath='{.status.readyReplicas}/{.status.replicas}'
```

## Common Patterns

### Local cluster with port-forwarding
Services accessed via `kubectl port-forward` or Istio ingress (*.localhost).

### Remote cluster with tunnel
Services accessed via cloud-specific tunnel or VPN.

### Hybrid (frontier pattern)
Infrastructure on remote cluster, port-forwarded to local.
Services built and deployed to local cluster pointing at port-forwarded infra.
