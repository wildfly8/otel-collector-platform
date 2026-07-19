# Implementation Plan: Central OpenTelemetry Collector

## Boundary

This project owns the shared OTLP gateway, generic admission/sanitation policy,
local LGTM environment, GCP runtime provisioning, and Grafana Cloud stack
provisioning. Producer repositories own SDK code, telemetry schemas, SLOs,
recording rules, dashboards, and product alerts.

Producer-facing behavior is published as the semantically versioned
`contracts/public/otel-ingest` package. Feature-local `contracts/` remain
internal design artifacts and redirects; producers do not consume them.

## Runtime design

1. OTLP/HTTP receiver authenticates a rotated bearer token.
2. `memory_limiter` is first in every pipeline.
3. Metrics pass through deterministic admission filters before sanitation.
4. Common sensitive attributes are removed from all signals.
5. Bounded normalization truncates surviving attributes.
6. `batch` is last and feeds one OTLP backend.
7. Collector detailed self-metrics are exported periodically to the same cloud
   backend and exposed for local scraping.

## Cloud design

- A pinned custom image contains the reviewed collector config.
- Artifact Registry stores the image.
- Secret Manager supplies ingest and backend credentials.
- Cloud Run terminates TLS, allows public invocation, and relies on Collector
  bearer authentication.
- `min-instances=0`, `max-instances=1`, 512 MiB memory.
- CPU remains available for the instance lifecycle because queues and timers
  continue after the OTLP handler returns.

## Verification

- Public contract package and version-link consistency validation.
- Collector config validate for cloud and merged local config.
- Terraform init/validate and disabled no-op plan.
- Local five-service health validation.
- OTLP JSON acceptance fixture proves valid metrics pass and invalid metrics
  are filtered.

Public contract releases use tags of the form
`contracts/otel-ingest/v<version>`. A behavior change updates the package
version, changelog, feature traceability, and acceptance evidence together.

