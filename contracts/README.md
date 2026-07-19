# Published contracts

`contracts/public/` is the only normative surface published for external
services. Producer applications MUST pin a released semantic version of the
`otel-ingest` contract and MUST NOT import this repository's `specs/`,
collector configuration, infrastructure, or internal workflows.

## Available contracts

- [`otel-ingest`](public/otel-ingest/README.md) — authenticated OTLP/HTTP
  ingestion, telemetry data constraints, and platform capabilities.

Each contract package contains a `VERSION` and `CHANGELOG.md`. Until a contract
registry is introduced, a release is identified by the repository tag
`contracts/<contract-name>/v<version>`. Consumers should resolve a tag rather
than copy files from a mutable branch.

The platform may change internal implementation without a public contract
release when externally observable behavior remains compatible.

## Terminology

"Producer" and "consumer" are used on two different axes:

- **Telemetry data flow**: a *telemetry producer* is an application that emits
  OTLP signals to this platform.
- **Contract dependency**: a *contract consumer* is any service that pins a
  released version of a contract published here; this platform is the
  *contract publisher*.

The same application is typically both: it produces telemetry while consuming
the `otel-ingest` contract that governs how that telemetry must be shaped.
Emitting telemetry never obligates an application to publish its own public
contract — that obligation arises only when another service depends on it.
