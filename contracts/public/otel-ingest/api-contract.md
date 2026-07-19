# API contract

## Protocol and endpoints

The platform accepts OTLP over HTTP using the standard OTLP JSON or protobuf
payload for each signal:

- `POST /v1/traces`
- `POST /v1/metrics`
- `POST /v1/logs`

The deployed endpoint uses HTTPS. Local development uses loopback HTTP.
OTLP/gRPC is not part of this contract.

Standard OTLP SDK exporters take a **base endpoint** (for example
`https://<gateway-host>`) and append `/v1/<signal>` themselves. Configure the
base URL only; do not include `/v1/...` in the exporter endpoint, or the SDK
will produce a doubled path.

Requests MUST set the standard OTLP `Content-Type`:

- `application/x-protobuf` for binary protobuf payloads;
- `application/json` for OTLP/JSON payloads.

Optional `Content-Encoding: gzip` request compression is accepted.

The concrete gateway URL and the ingest token are per-deployment values
provisioned out of band by the platform operator (see the repository README's
cloud provisioning section). They are intentionally not part of this versioned
contract.

## Authentication

Every request MUST include:

```text
Authorization: Bearer <ingest-token>
```

The token is a platform-issued secret. Producers MUST NOT log, emit, or commit
it. Missing or invalid credentials are rejected.

## Delivery and failure behavior

Producers MUST use bounded, non-blocking telemetry export with normal OTLP
retry and exponential backoff. Platform unavailability or rejection MUST NOT
cause a product request to fail.

An accepted OTLP request does not guarantee durable backend storage. The
platform may subsequently shed load, retry backend delivery, or drop telemetry
that violates the data contract. OTLP partial-success responses and
reason-labelled rejection details are not guaranteed.

The platform exports accepted telemetry to one configured backend; it does not
provide a query API to producer applications.
