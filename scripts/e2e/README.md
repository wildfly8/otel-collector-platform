# E2E test suites

End-to-end tests are split by **runtime** (where the collector runs) and
**backend** (where telemetry lands).

| Suite | Entry point | Collector | Backend |
|-------|-------------|-----------|---------|
| **Local** | `scripts/run-e2e-local.ps1` | k3d/k3s (`otel-collector`) | Local LGTM (Prometheus, Tempo, Loki, Grafana) |
| **Cloud** | `scripts/run-e2e-cloud.ps1` | GCP Cloud Run | Grafana Cloud LGTM stack |

Legacy script paths (`scripts/test-*.ps1`) forward to `scripts/e2e/local/` for
backward compatibility with the constitution quality gates.

## Local E2E

```powershell
pwsh scripts/local-up.ps1
pwsh scripts/run-e2e-local.ps1
```

Runs health validation, metric admission policy, signal sanitation canary, and
memory/load tests against the k3s stack (`scripts/e2e/lib/LocalRuntime.ps1`).

Optional environment variables:

- `OTEL_COLLECTOR_OTLP_URL` — default `http://127.0.0.1:4318`
- `OTEL_COLLECTOR_HEALTH_URL` — default `http://127.0.0.1:13133`
- `OTEL_GRAFANA_URL` — default `http://127.0.0.1:3002`
- `OTEL_K8S_NAMESPACE` — default `otel-platform`
- `OTEL_COLLECTOR_BEARER_TOKEN` — default local dev token

See `scripts/e2e/local/README.md` and `k3s/README.md`.

## Cloud E2E

Requires a provisioned Cloud Run service and Grafana Cloud stack:

```powershell
pwsh scripts/provision-cloud.ps1 -Phase e2e-cloud
# or
pwsh scripts/run-e2e-cloud.ps1
```

Sub-suites:

- `scripts/e2e/cloud/gcp/` — OTLP ingest to Cloud Run (metrics, traces, logs)
- `scripts/e2e/cloud/grafana/` — query Grafana Cloud Prometheus, Loki, and Tempo
  for exported markers

Configuration is loaded from environment variables, then from Terraform outputs
and gitignored `infra/gcp/terraform.tfvars`. After `grafana` apply, the
`e2e_query_token` output supplies read access for backend verification.

Override with env vars (see `scripts/e2e/cloud/env.example`).

Publish the **E2E dashboard** (Grafana Cloud LGTM panels for test telemetry):

```powershell
pwsh scripts/push-e2e-dashboard.ps1
# or
pwsh scripts/provision-cloud.ps1 -Phase e2e-dashboard
```

Open: `https://<stack>.grafana.net/d/platform-e2e-cloud` (folder **Platform**).

Flags:

- `-SkipGcp` — only verify Grafana Cloud query APIs (re-sends OTLP from script)
- `-SkipGrafana` — only verify Cloud Run ingest acceptance
