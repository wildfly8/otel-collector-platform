# OTLP ingest contract

**Contract**: `otel-ingest`  
**Version**: `1.0.1`  
**Publisher**: OTel Collector Platform

This package is the complete public specification surface consumed by
telemetry producer applications:

- [`contract.yaml`](contract.yaml) — machine-readable package identity,
  protocol, version, release tag, and surface index.
- [`api-contract.md`](api-contract.md) — transport, endpoints, authentication,
  and failure behavior.
- [`data-contract.md`](data-contract.md) — resource identity, admission bounds,
  sanitation, and normalization.
- [`capability.md`](capability.md) — platform guarantees and ownership limits.
- [`CHANGELOG.md`](CHANGELOG.md) — compatibility history.

The package defines no application metric names, trace semantics, SLOs,
dashboards, or alerts. Consumers MUST NOT depend on internal files under
`specs/`, `collector/`, `infra/`, or `local/`.

## Versioning

Consumers pin the full package version. Contract versions use semantic
versioning:

- **MAJOR**: an incompatible producer obligation or observable behavior,
  including a new required field, tighter admission bound, endpoint removal,
  or authentication scheme change.
- **MINOR**: a backward-compatible capability or optional field.
- **PATCH**: a clarification that does not alter producer or platform behavior.

Until a registry exists, version `1.0.1` is published by repository tag
`contracts/otel-ingest/v1.0.1`.
