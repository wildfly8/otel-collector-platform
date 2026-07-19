# Backend export contract

> **Internal contract.** This describes the platform-to-backend runtime edge.
> It is not part of the public producer contract surface.

- A deployed gateway exports traces, metrics, and logs through one
  `otlphttp/backend` exporter to one Grafana Cloud stack.
- Backend credentials have write-only telemetry scopes.
- No second telemetry exporter may appear in deployed pipelines.
- Application teams own their folders, dashboards, recording rules, and alert
  definitions. The platform may issue scoped provisioning credentials without
  embedding product-specific resources here.
- Collector self-telemetry is bounded and exposes accepted/sent counters,
  memory refusals, queue pressure, and exporter failures. Aggregate filtered
  volume is inferred after batch settling from accepted minus sent; per-reason
  behavior is covered by policy fixtures. Local Prometheus scrapes port 8888;
  cloud self-metrics export periodically to the same Grafana OTLP gateway.

