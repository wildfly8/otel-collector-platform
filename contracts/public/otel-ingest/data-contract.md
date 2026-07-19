# Data contract

## Resource identity

Every signal SHOULD provide these bounded resource attributes:

- `service.name` — required for metrics; non-empty, stable, at most 64
  characters, and not an SDK default matching `unknown_service*`.
- `service.version` — bounded release identifier.
- `deployment.environment.name` — bounded environment name.
- `service.namespace` — optional bounded organizational namespace.

Metric resources with more than 24 attributes are rejected. Trace and log
identity is sanitized and normalized, but producers remain responsible for
valid resource identity at source.

## Metric admission

The platform drops a metric datapoint before export when any condition is true:

- `service.name` is missing, empty, an `unknown_service*` default, or longer
  than 64 characters;
- the resource has more than 24 attributes;
- the datapoint has more than 16 attributes;
- a prohibited resource key is present:
  `user.id`, `user.email`, `enduser.id`, `session.id`, `request.id`,
  `url.full`, `url.query`, or `db.statement`;
- a prohibited datapoint key is present:
  `user.id`, `user.email`, `enduser.id`, `session.id`, `request.id`,
  `client.id`, `email`, `url.full`, `url.query`, `http.url`, `http.target`,
  `exception.message`, `db.statement`, or `messaging.message.id`;
- `http.route`, `error.type`, or `server.address` is longer than 128
  characters.

These are deterministic per-datapoint risk bounds, not a calculation of global
distinct series. Producers MUST design and monitor bounded metric schemas.

## Sanitation and normalization

For traces, metrics, and logs, the platform removes known credential,
identity, content, and raw-query attributes when present. This includes
authorization and cookie headers, user/session/request identity, raw URL
components, exception details, database statements, and message bodies.

The platform removes query strings from `http.route`, clears span status
messages for error spans, and truncates surviving values to implementation
bounds (128 characters for metric datapoint attributes and 256 characters for
resource, span, and log attributes).

Sanitation is defense in depth, not permission to send sensitive data.
Producers MUST NOT emit payloads, prompts, answers, documents, credentials,
raw headers, raw URLs or queries, stack traces, database statements, user
identity, session identity, or request identity as telemetry attributes.

## Compatibility

Producers may emit additional bounded semantic attributes not prohibited
above. The platform does not require application-specific metric names,
events, routes, attributes, or schemas.
