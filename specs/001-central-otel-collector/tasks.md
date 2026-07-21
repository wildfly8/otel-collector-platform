# Tasks: Central OpenTelemetry Collector

- [X] T001 Define platform/producer ownership boundary.
- [X] T002 Specify generic authenticated OTLP ingest contract.
- [X] T003 Implement memory limiter first and bounded batch last.
- [X] T004 Implement metric admission for missing/default service identity,
  attribute-count limits, prohibited dimensions, and oversized guarded values.
- [X] T005 Implement cross-signal sensitive-attribute sanitation and bounded
  normalization.
- [X] T006 Export to exactly one Grafana Cloud OTLP backend.
- [X] T007 Export detailed Collector self-telemetry to the backend and expose it
  for local scraping.
- [X] T008 Create loopback-only local LGTM k3s/k3d environment (`k3s/`,
  `scripts/local-up.ps1`; `compose.yaml` retained as legacy reference).
- [X] T009 Create plan-safe GCP Terraform with Artifact Registry, Secret
  Manager, and Cloud Run.
- [X] T010 Create plan-safe Grafana Cloud Terraform with OTLP and producer
  provisioning credentials; no product dashboards.
- [X] T011 Add collector/config/Terraform validation automation.
- [X] T012 Add live metric-admission acceptance fixture.
- [X] T013 Operator live apply: `scripts/provision-cloud.ps1` phases with Grafana
  Portal token and GCP project (local tfvars + state; not in git). Cloud runtime
  verified by `scripts/run-e2e-cloud.ps1` (ingest + LGTM query).
- [X] T014 Author platform drop/export/refusal alerts and an 8,000 active-series
  warning threshold; publish the rules to hosted ruler during T013.
- [X] T015 Publish `contracts/public/otel-ingest@1.0.1` with API, data,
  capability, semantic-version, and changelog surfaces.
- [X] T016 Add public-contract package validation and link it from the standard
  configuration gate.
- [X] T017 Align admission acceptance fixtures with the published oversized
  guarded-value behavior.

## Phase 2: Convergence

- [X] T018 Add an automated memory/load test (`scripts/test-memory-load.ps1`)
  that drives sustained load and asserts no container OOM or restart with an
  active, observable `memory_limiter` per SC-003 (Constitution V — Resource
  Protection Ordering).
- [X] T019 Add a cross-signal sanitation canary (`scripts/test-signal-canary.ps1`)
  proving zero known sensitive attributes on exported **traces and logs** past
  the platform boundary, not only metrics, per SC-004 and INV-COL-006.
- [X] T020 Restructure E2E suites under `scripts/e2e/{local,cloud,lib}` with
  entry points `scripts/run-e2e-local.ps1` and `scripts/run-e2e-cloud.ps1`.
- [X] T021 Migrate default local runtime from Compose to k3d/k3s (`k3s/`,
  `scripts/local-up.ps1`, `scripts/e2e/lib/LocalRuntime.ps1`).
- [X] T022 Add Grafana Cloud E2E observability dashboard
  (`monitoring/e2e-dashboard.json`, `scripts/push-e2e-dashboard.ps1`,
  `provision-cloud.ps1 -Phase e2e-dashboard`).

