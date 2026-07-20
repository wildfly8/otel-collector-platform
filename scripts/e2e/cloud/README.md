# Cloud E2E (GCP Cloud Run + Grafana Cloud)

## GCP Cloud Run (`gcp/`)

`test-cloud-run-ingest.ps1` posts OTLP/HTTP metrics, traces, and logs to the
public Cloud Run URL with the platform ingest bearer token. Success means HTTP
2xx on all three signal paths.

## Grafana Cloud LGTM (`grafana/`)

`test-lgtm-export.ps1` sends marked telemetry (or reuses a prior ingest
context), then queries:

- **Prometheus** — `cloud_e2e_export_total{service_name="e2e-metrics"}`
- **Loki** — `{service_name="e2e-logs"}` with marker in log line
- **Tempo** — trace ID lookup

Queries use Basic auth (`prometheus_user_id` / instance ID + query token).

## Configuration

Resolved in order: environment variable → Terraform output → `terraform.tfvars`.

| Variable | Source |
|----------|--------|
| `CLOUD_RUN_URI` | `infra/gcp` output `cloud_run_uri` |
| `INGEST_BEARER_TOKEN` | `infra/gcp/terraform.tfvars` `ingest_bearer_token` |
| `GRAFANA_CLOUD_PROM_URL` | `infra/grafana-cloud` output `prometheus_url` |
| `GRAFANA_CLOUD_PROM_USER` | output `prometheus_user_id` |
| `GRAFANA_CLOUD_LOGS_URL` | output `logs_url` |
| `GRAFANA_CLOUD_TEMPO_URL` | output `traces_url` |
| `GRAFANA_CLOUD_QUERY_TOKEN` | output `e2e_query_token` (after grafana apply) |

Re-apply `infra/grafana-cloud` once to create the `e2e-query` access policy
and token if your stack predates this resource.

## E2E dashboard

`scripts/push-e2e-dashboard.ps1` publishes `monitoring/e2e-dashboard.json` to
Grafana Cloud (folder **Platform**, uid `platform-e2e-cloud`). It shows E2E
metrics, logs, and traces in LGTM. Cloud Run HTTP ingest success is **not** on
this dashboard — see GCP Console logs (`resource.type=cloud_run_revision`).

Copy `env.example` to set overrides without Terraform.
