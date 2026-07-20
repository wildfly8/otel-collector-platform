# OTel Collector Platform

A standalone, application-neutral OpenTelemetry gateway and its platform
provisioning. It accepts authenticated OTLP/HTTP from multiple services,
enforces shared safety and resource policies, and exports to one Grafana Cloud
stack.

This repository deliberately does **not** own application instrumentation,
application SLO definitions, or application dashboards. Each producer owns
those artifacts and identifies itself with a non-empty `service.name`.

## Repository boundaries

- `collector/` — generic collector configuration and policy.
- `contracts/public/` — versioned contracts published to producer services.
- `compose.yaml` — loopback-only local LGTM development stack.
- `infra/gcp/` — Cloud Run deployment infrastructure.
- `infra/grafana-cloud/` — Grafana Cloud stack and platform credentials.
- `specs/001-central-otel-collector/` — Feature 001 specification and design.

## Spec-driven development

This repository follows Spec-Kit SDD. Governance lives in
`.specify/memory/constitution.md` (v1.1.1): application neutrality, federated
public contracts, privacy and cardinality bounds, memory-limiter-first /
batch-last ordering, single backend, and plan-safe zero-cost infrastructure.
There is no domain-compiler pipeline here (no `npm run domain:*`); quality
gates include `scripts/check-public-contract.ps1`,
`scripts/validate.ps1`, `terraform validate` in both `infra/` modules,
`scripts/test-metric-policy.ps1`, `scripts/test-signal-canary.ps1`, and
`scripts/test-memory-load.ps1` — see the constitution's Quality Gates table.

## Producer contract

Producer applications consume only the versioned
[`otel-ingest` public contract](contracts/public/otel-ingest/README.md).
Version `1.0.1` is identified by release tag
`contracts/otel-ingest/v1.0.1`. Consumers pin a release; they do not copy or
import `specs/`, collector configuration, infrastructure, or private
workflows. The platform likewise imports no producer domain specifications.

## Platform policy

The normative admission, sanitation, and normalization behavior is defined in
the public
[`data-contract.md`](contracts/public/otel-ingest/data-contract.md).
The gateway uses deterministic bounds because a stock Collector cannot
calculate future global distinct-series cardinality from one OTLP request.

“Reject” means the filter processor drops the invalid datapoint. The stock
filter processor exposes no reason-labelled drop counter and OTLP
partial-success responses are not guaranteed; operators infer aggregate drops
from the bounded receiver-accepted versus exporter-sent counter delta and use
acceptance fixtures to verify each policy reason.

## Local start

```powershell
Copy-Item .env.example .env
docker compose up -d
pwsh scripts/validate.ps1 -PostStart
```

Local endpoints:

- OTLP/HTTP: `http://127.0.0.1:4318`
- Collector health: `http://127.0.0.1:13133`
- Grafana: `http://127.0.0.1:3002`

Producer repositories may copy app-owned Prometheus rule YAML and dashboard
JSON into ignored `local/producer/`. Compose mounts that directory read-only;
the platform repository never versions those product artifacts.

## Cloud provisioning order

1. Apply `infra/grafana-cloud/`.
2. Apply `infra/gcp/` with `enable_foundation=true` to create Artifact Registry.
3. Build and push the pinned Collector image to that repository.
4. Apply `infra/gcp/` with `enable_runtime=true`, the immutable image URI, and
   Grafana OTLP credentials.
5. Configure producer applications with the Cloud Run URL and ingest token.

Publish platform health/cardinality rules after Grafana apply:

```powershell
$env:GRAFANA_CLOUD_PROM_URL    = terraform output -raw prometheus_url
$env:GRAFANA_CLOUD_PROM_USER   = terraform output -raw prometheus_user_id
$env:GRAFANA_CLOUD_RULES_TOKEN = terraform output -raw producer_rules_token
pwsh scripts/push-platform-rules.ps1
```

Both Terraform modules are disabled by default. Cloud Run uses
`min-instances=0`, `max-instances=1`, and CPU available for the full instance
lifecycle so batching/export can complete outside an inbound request. The
deployment is designed to fit free allotments at low volume, but infrastructure
automation cannot truthfully guarantee a $0 bill; budgets and usage alerts are
mandatory safeguards.

## Cloud provisioning script

Local `infra/*/terraform.tfvars` files (gitignored) are scaffolded with
placeholders. After you set real values, run phases in order:

```powershell
pwsh scripts/provision-cloud.ps1 -Phase check
pwsh scripts/provision-cloud.ps1 -Phase grafana
pwsh scripts/provision-cloud.ps1 -Phase gcp-foundation
pwsh scripts/provision-cloud.ps1 -Phase image
pwsh scripts/provision-cloud.ps1 -Phase gcp-runtime
pwsh scripts/provision-cloud.ps1 -Phase rules
```

See `specs/001-central-otel-collector/quickstart.md` for placeholder fields and
prerequisites (`gcloud`, Grafana Cloud Portal token, GCP project id).
