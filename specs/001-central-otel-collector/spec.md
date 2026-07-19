# Feature Specification: Central OpenTelemetry Collector

**Feature Branch**: `001-central-otel-collector`
**Created**: 2026-07-18
**Status**: Approved
**Input**: Separate the reusable central OpenTelemetry Collector and its
GCP/Grafana provisioning from any one application's instrumentation.

## Summary

- **What this feature delivers**: A reusable telemetry gateway for multiple
  applications, with authenticated ingestion, privacy and cardinality
  guardrails, overload protection, one managed backend, local development, and
  repeatable cloud provisioning.
- **Surface type**: Operator infrastructure and OTLP API only; no end-user UI.
- **Who it affects**: Platform operators and application teams exporting
  traces, metrics, and logs.
- **Must not own**: Producer instrumentation, application-specific telemetry
  schemas, service-level objectives, dashboards, alert thresholds, or product
  access control.

## Domain Mapping

**Primary bounded context**: Telemetry Platform

| Entity | Role | Owner context |
|--------|------|---------------|
| Telemetry Gateway | aggregate root | Telemetry Platform |
| Producer Identity | created | Telemetry Platform |
| Telemetry Admission Policy | created | Telemetry Platform |
| Telemetry Batch | created | Telemetry Platform |
| Backend Destination | referenced | Telemetry Platform |
| Producer Signal | observed, never semantically owned | Producer application |
| Application SLO | external, never evaluated by platform policy | Producer application |

**Cross-Project Contract Edges**:

| Project | Relationship | Contract |
|---------|--------------|----------|
| Producer applications | consume the platform's versioned ingest contract; platform imports no producer spec | `contracts/public/otel-ingest@1.0.0` |
| Grafana Cloud | sole deployed storage/query backend | `contracts/backend-export.md` |
| GCP | hosts the public HTTPS gateway | deployment contract |

**Handoffs**:

| From | To | Contract | Restricts |
|------|----|----------|-----------|
| Producer application | Telemetry Platform | authenticated OTLP/HTTP | usable `service.name`; no prohibited content or identity dimensions |
| Telemetry Platform | Grafana Cloud | sanitized OTLP | one backend only; no fan-out |
| Telemetry Platform | Operator | self-telemetry and policy counters | no producer payload content |

**Invariants**:

- **INV-COL-001**: Every accepted signal has a non-empty, non-default
  `service.name`; invalid metric datapoints are dropped before export.
- **INV-COL-002**: Metrics with deterministic cardinality hazards are dropped:
  more than 16 datapoint attributes, prohibited identity/content dimensions,
  or selected unbounded values over 128 characters.
- **INV-COL-003**: Memory limiting precedes all expensive processing and batch
  processing is last before export.
- **INV-COL-004**: The deployed gateway exports to exactly one backend and
  never fans out producer telemetry.
- **INV-COL-005**: Gateway policy is application-neutral; no product-specific
  metric name, event name, SLO, route, or dashboard is required for admission.
- **INV-COL-006**: Authentication material and known sensitive URL, user,
  session, request, and content attributes do not cross the backend boundary.
- **INV-COL-007**: Aggregate policy drops are inferable from bounded
  receiver-accepted versus exporter-sent counters; memory refusals and export
  failures remain directly observable. Per-reason behavior is proven by
  acceptance fixtures because the stock filter has no reason-labelled counter.
- **INV-COL-008**: Producer-facing behavior is published only through a
  semantic version of `contracts/public/otel-ingest`; the platform neither
  requires producer-internal specifications nor exposes its internal domain
  model as a consumer dependency.

## Saga and state machines

### SAGA-COL-001 — Admit and export telemetry

| ID | From | Event | To | Side effects | Compensation |
|----|------|-------|----|--------------|--------------|
| CG01 | received | authentication_valid | policy_check | start bounded processing | reject unauthorized request |
| CG02 | policy_check | signal_valid | buffered | sanitize and normalize | — |
| CG03 | policy_check | metric_invalid | dropped | increment filter self-telemetry | producer fixes schema |
| CG04 | buffered | batch_ready | export_pending | create bounded batch | flush on timeout |
| CG05 | export_pending | backend_accepted | exported | record exporter success | — |
| CG06 | export_pending | backend_unavailable | degraded | record export failure; bounded retry | operator restores backend |
| CG07 | any_processing | memory_pressure | refused | shed load before expensive work | producer retries with backoff |

## User Scenarios & Testing

### User Story 1 - Share one safe telemetry gateway (Priority: P1)

As a platform operator, I want multiple services to export through one gateway
without one producer contaminating another's identity or exhausting resources.

**Independent Test**: Send valid OTLP from two named services and invalid OTLP
with missing/default service identity; valid signals reach the sole backend and
invalid metric datapoints do not.

**Acceptance Scenarios**:

1. Given two valid producer identities, when both export telemetry, then both
   remain distinguishable by `service.name`.
2. Given a metric without a usable service identity, when it is received, then
   its datapoints are dropped before export.
3. Given memory pressure, when the configured limit is reached, then the
   gateway sheds telemetry without exhausting its container.

### User Story 2 - Contain cardinality and sensitive dimensions (Priority: P1)

As a platform operator, I want deterministic high-cardinality and sensitive
metric dimensions rejected before they create cost or privacy incidents.

**Independent Test**: Export datapoints containing too many dimensions,
forbidden identity keys, and oversized bounded values; each is dropped while a
bounded valid datapoint passes.

**Acceptance Scenarios**:

1. A datapoint with more than 16 attributes is dropped.
2. A datapoint with user/session/request/content/raw-URL dimensions is dropped.
3. A bounded datapoint using common semantic dimensions is exported.
4. Actual active-series growth is monitored at the backend because per-request
   filtering cannot predict future global cardinality exactly.

### User Story 3 - Provision repeatably (Priority: P2)

As an operator, I want plan-safe infrastructure automation for the collector
host and its sole backend.

**Independent Test**: Validate both modules with runtime creation disabled;
then apply with operator credentials and verify authenticated public ingestion.

## Edge Cases

- SDKs may synthesize `unknown_service` names; these are invalid producer
  identities, not acceptable defaults.
- One datapoint can have few attributes yet still generate unbounded values;
  known dangerous keys and value lengths are checked, while backend series
  monitoring catches emergent cases.
- The stock filter processor drops individual datapoints but does not promise
  an OTLP partial-success response to the producer.
- Scale-to-zero can interrupt in-memory batches. The gateway flush interval is
  short, CPU remains available while an instance exists, and producers retain
  normal retry behavior.

## Requirements

### Functional Requirements

- **FR-001**: The gateway MUST accept authenticated OTLP/HTTP traces, metrics,
  and logs from multiple producer applications.
- **FR-002**: All pipelines MUST apply memory limiting first and batching last.
- **FR-003**: The metric pipeline MUST drop datapoints governed by
  INV-COL-001 or INV-COL-002 before export.
- **FR-004**: The gateway MUST remove known authentication, user, session,
  request, raw URL/query, email, and content attributes from accepted signals.
- **FR-005**: The gateway MUST preserve standard bounded resource identity and
  common semantic-convention attributes without requiring application-specific
  names.
- **FR-006**: Deployed telemetry MUST export to exactly one Grafana Cloud OTLP
  destination.
- **FR-007**: Collector self-telemetry MUST expose accepted and sent signal
  counters, receiver refusals, queue pressure, memory pressure, and exporter
  failures using bounded labels; acceptance tests MUST prove each filter reason.
- **FR-008**: Infrastructure plans MUST create no runtime or paid resource
  unless an operator explicitly enables it and supplies credentials.
- **FR-009**: Cloud deployment MUST expose public HTTPS, authenticate producer
  requests, use at most one instance, and make CPU available while that
  instance drains asynchronous batches.
- **FR-010**: The platform MUST provide a loopback-only local stack for
  integration testing.
- **FR-011**: Producer-specific SLOs, dashboards, recording rules, alerts, and
  trace-sampling semantics MUST remain producer-owned.
- **FR-012**: The platform MUST publish its producer-facing API, data, and
  capability guarantees as one semantically versioned public contract package;
  incompatible behavior MUST require a major contract release.

### Key Entities

- **Telemetry Gateway**: Authenticated policy enforcement and export boundary.
- **Producer Identity**: Bounded resource identity led by `service.name`.
- **Telemetry Admission Policy**: Generic conditions for accepting, sanitizing,
  or dropping signals.
- **Telemetry Batch**: Bounded collection flushed by size or time.
- **Backend Destination**: The one configured deployed OTLP destination.

## Success Criteria

- **SC-001**: Valid test signals from at least two named services reach the
  backend while preserving distinct identities.
- **SC-002**: 100% of acceptance fixtures with missing/default service names,
  more than 16 datapoint attributes, forbidden identity dimensions, or
  oversized guarded values are absent from exported metrics.
- **SC-003**: A load test reaches the memory policy without container OOM.
- **SC-004**: Canary tests find zero known sensitive attributes after the
  platform boundary.
- **SC-005**: Configuration and both infrastructure modules validate
  automatically from a clean checkout.
- **SC-006**: No deployed configuration exports a signal to more than one
  backend.
- **SC-007**: The public-contract validation gate confirms package shape,
  version consistency, required sections, and the feature redirect from a
  clean checkout.

## Assumptions

- Producer applications remain responsible for not putting payload content into
  telemetry; platform sanitation is defense in depth.
- “Excessive cardinality” is enforced through deterministic per-datapoint
  bounds plus backend-wide active-series monitoring, not an impossible exact
  prediction from one OTLP request.
- Cloud free allotments are usage limits, not a guarantee of a zero invoice.

## Out of Scope

- Application instrumentation and SDK lifecycle.
- Product-specific SLOs, dashboards, recording rules, and alerts.
- Exact global distinct-series calculation inside the Collector.
- Multiple backend fan-out.
- Multi-replica tail sampling.
