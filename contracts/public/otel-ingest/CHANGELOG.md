# Changelog

All notable changes to the `otel-ingest` public contract are recorded here.

## 1.0.1 — 2026-07-19

- Clarify base-endpoint configuration versus per-signal paths for standard
  OTLP SDK exporters.
- Document required `Content-Type` values and accepted gzip request
  compression.
- State that the gateway URL and ingest token are provisioned out of band and
  are not part of this versioned contract.
- No producer obligation or platform behavior changed (PATCH).

## 1.0.0 — 2026-07-19

- Publish authenticated OTLP/HTTP trace, metric, and log endpoints.
- Define producer identity, privacy, metric admission, and normalization rules.
- Define platform guarantees, non-guarantees, and producer responsibilities.
- Establish semantic versioning and repository tag publication.
