# Capability contract

## Platform guarantees

For the deployed service, the platform:

- exposes authenticated OTLP/HTTP ingestion for traces, metrics, and logs;
- applies memory protection before expensive processing;
- enforces the metric admission rules in `data-contract.md`;
- sanitizes and bounds telemetry before export;
- batches only after admission, sanitation, and normalization;
- exports through exactly one configured backend destination;
- exposes bounded self-telemetry for accepted/sent volume, memory refusals,
  queue pressure, and exporter failures.

Acceptance tests prove representative admission outcomes. Aggregate policy
drops are inferable from receiver-accepted and exporter-sent counters after
batch settling; per-reason production counters are not guaranteed.

## Producer responsibilities

Each producer owns:

- SDK instrumentation and non-blocking exporter configuration;
- application telemetry schemas and semantic conventions;
- privacy and data minimization at source;
- sampling behavior;
- SLOs, recording rules, dashboards, and product alerts;
- validation against the pinned version of this contract.

## Non-capabilities

The platform does not:

- own or interpret application domain events or product semantics;
- guarantee acceptance of telemetry that violates the data contract;
- guarantee durable storage from an accepted HTTP response;
- calculate exact global metric cardinality;
- provide producer-specific dashboards, SLOs, or alert thresholds;
- expose Grafana Cloud or other backend contracts to producers.
