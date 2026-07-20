# k3s local deployment (default local runtime)

The **default local stack** is k3s via [k3d](https://k3d.io/) on Windows/macOS/Linux
with Docker. Docker Compose (`compose.yaml`) remains in the repo for reference but
is no longer the primary local path.

## Quick start

Prerequisites: Docker Desktop, [k3d](https://k3d.io/), `kubectl`.

```powershell
pwsh scripts/local-up.ps1
pwsh scripts/validate.ps1 -PostStart
pwsh scripts/run-e2e-local.ps1
```

`local-up.ps1` stops any running Compose stack for this repo, then creates or
reuses the k3d cluster and applies `k3s/` manifests.

Endpoints (same ports as the former Compose stack):

- OTLP/HTTP: `http://127.0.0.1:4318`
- Collector health: `http://127.0.0.1:13133`
- Grafana: `http://127.0.0.1:3002` (admin / admin)

Teardown:

```powershell
pwsh scripts/local-down.ps1
```

Recreate the cluster (e.g. after port mapping changes):

```powershell
pwsh scripts/local-up.ps1 -RecreateCluster
```

## Tests

All local gates use the k3s stack:

| Script | Role |
|--------|------|
| `scripts/validate.ps1` | Config + k8s deployment health |
| `scripts/run-e2e-local.ps1` | Full local E2E suite |
| `scripts/test-*.ps1` | Individual gates (wrappers) |

In-cluster HTTP checks use `kubectl exec deploy/prometheus -- wget ...` via
`scripts/e2e/lib/LocalRuntime.ps1`.

Override endpoints with `OTEL_COLLECTOR_OTLP_URL`, `OTEL_COLLECTOR_HEALTH_URL`,
`OTEL_GRAFANA_URL`, or `OTEL_K8S_NAMESPACE` when needed.

## What you learn

- `Namespace`, `Deployment`, `Service`, `ConfigMap`, `LoadBalancer`
- Kustomize `configMapGenerator` reusing `collector/`, `local/`, `monitoring/`
- Same collector policy config as before; only orchestration changed

## Files

| Path | Role |
|------|------|
| `kustomization.yaml` | Kustomize entry |
| `otel-collector.yaml` | Collector Deployment + LoadBalancer |
| `prometheus.yaml`, `tempo.yaml`, `loki.yaml`, `grafana.yaml` | LGTM backends |
| `../scripts/local-up.ps1` | Stop Compose + start k3d/k3s |
| `../scripts/k3s-up.ps1` | Cluster create + `kubectl apply -k` |
| `../scripts/k3s-down.ps1` | Tear down |
