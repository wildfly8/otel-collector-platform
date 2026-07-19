# Research: Central OpenTelemetry Collector

## Decision 1 — Deterministic cardinality admission

**Decision**: Drop metric datapoints with unusable service identity, more than
16 dimensions, known identity/content dimensions, or oversized guarded values.
Monitor actual active-series growth in the backend.

**Reason**: Cardinality is the number of distinct label sets over time. A stock
Collector filter evaluates one datapoint and has no exact view of all future or
backend-resident series. Calling an attribute-count check “cardinality” alone
would be incorrect.

## Decision 2 — Denylist sanitation, not an application allowlist

**Decision**: Delete common sensitive keys and bound surviving values.

**Reason**: A central platform must preserve producer-specific bounded semantic
attributes. A single global allowlist would silently destroy legitimate
application telemetry and couple this project to every producer schema.

## Decision 3 — No platform-owned application tail sampling

**Decision**: Producer teams own trace-sampling semantics.

**Reason**: “slow” and “error” policies depend on application objectives, and
central tail sampling introduces state, delayed decisions, and horizontal
scaling constraints.

## Decision 4 — Cloud Run CPU remains available

**Decision**: Use lifecycle CPU (`cpu_idle=false`) with zero minimum instances.

**Reason**: The Collector acknowledges OTLP before asynchronous batch, retry,
and export work necessarily completes. Request-only CPU can freeze that work.
This is designed to fit low-volume free allotments, not represented as a
guaranteed $0 host.

## Decision 5 — Product resources remain producer-owned

**Decision**: Grafana stack and scoped provisioning credentials are platform
resources; dashboards, recording rules, SLOs, and product alerts stay in
producer repositories.

## Decision 6 — Publish a versioned producer contract

**Decision**: Publish API, data, and capability guarantees in
`contracts/public/otel-ingest`, versioned independently with semantic
versioning and repository release tags. Keep feature-local contracts,
collector configuration, infrastructure, and sagas internal.

**Reason**: Producer applications need a stable semantic boundary without
coupling to this service's internal domain theory or mutable implementation.
This enables federated SDD and deterministic consumer pinning without copying
spec trees or introducing a full contract registry before it is needed.

