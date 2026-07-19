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
- [X] T008 Create loopback-only local LGTM Compose environment.
- [X] T009 Create plan-safe GCP Terraform with Artifact Registry, Secret
  Manager, and Cloud Run.
- [X] T010 Create plan-safe Grafana Cloud Terraform with OTLP and producer
  provisioning credentials; no product dashboards.
- [X] T011 Add collector/config/Terraform validation automation.
- [X] T012 Add live metric-admission acceptance fixture.
- [ ] T013 Apply Grafana Cloud and GCP modules with operator credentials.
- [X] T014 Author platform drop/export/refusal alerts and an 8,000 active-series
  warning threshold; publish the rules to hosted ruler during T013.
- [X] T015 Publish `contracts/public/otel-ingest@1.0.0` with API, data,
  capability, semantic-version, and changelog surfaces.
- [X] T016 Add public-contract package validation and link it from the standard
  configuration gate.
- [X] T017 Align admission acceptance fixtures with the published oversized
  guarded-value behavior.

