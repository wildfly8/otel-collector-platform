<!-- Sync Impact Report
- Version: 1.0.0 → 1.1.0
- Added principle: III. Federated Public Contracts
- Renumbered principles: former III–VII → IV–VIII
- Added: versioned `contracts/public/otel-ingest` publication surface
- Updated:
  - ✅ `.specify/templates/spec-template.md`
  - ✅ `.specify/templates/plan-template.md`
  - ✅ `.specify/templates/tasks-template.md`
  - ✅ `.specify/templates/constitution-template.md`
  - ✅ `README.md`
  - ✅ Feature 001 spec, plan, research, quickstart, tasks, and checklist
- Removed: producer-facing authority from feature-local `contracts/`
- Deferred: external registry and reverse-consumer CI until multiple repositories
  consume published contract releases
-->

# OTel Collector Platform Constitution

This repository is a **standalone infrastructure microservice**: a central,
multi-producer OpenTelemetry Collector gateway with its own local LGTM stack
and plan-safe GCP / Grafana Cloud provisioning. It serves many producer
applications (first consumer: `agentic-foundation`) and owns **no** product
feature, UI, or application telemetry semantics.

## Core Principles

### I. Spec-First Delivery
Every feature begins with a written specification in `specs/` before
implementation. Code, collector configuration, and Terraform must trace back
to functional requirements, invariants (`INV-COL-*`), and user stories.
`spec.md` is the domain theory — not merely user stories. Multi-step flows
document `## Saga and state machines` (e.g. **SAGA-COL-001** admit-and-export)
in the owning `spec.md`.

### II. Application Neutrality (NON-NEGOTIABLE)
The platform is a **generic telemetry gateway**. Admission, sanitation, and
export policy MUST NOT require or reference any product-specific metric name,
event name, route, SLO, dashboard, or alert threshold. Producer-specific
observability assets (recording rules, dashboards, alerts, sampling semantics)
remain **producer-owned**; the platform may host copies locally under
`local/producer/` for integration testing only (gitignored, never SSOT).
Anything that would make one producer's vocabulary a platform admission
requirement violates INV-COL-005 and MUST be rejected at review.

### III. Federated Public Contracts
`contracts/public/` is the **only** normative surface published to producer
applications. Public contract packages MUST be independently consumable,
carry a semantic `VERSION` and changelog, and separate API, data, and
capability guarantees from internal domain and implementation details.
Producers MUST pin a released contract version and MUST NOT import `specs/`,
collector configuration, infrastructure, or private workflows. This project
MUST NOT import producer specifications, domain models, SLOs, or dashboards as
normative inputs.

Contract compatibility follows semantic versioning: MAJOR for incompatible
producer obligations or observable behavior, MINOR for backward-compatible
capabilities, and PATCH for non-semantic clarification. Every public behavior
change MUST update the contract, acceptance evidence, changelog, and version
in the same change. Until a registry exists, releases are published using
repository tags of the form `contracts/<name>/v<version>`.

### IV. Privacy and Bounded Cardinality by Default
The gateway enforces defense-in-depth **denylist sanitation** (auth material,
user/session/request identity, raw URL/query, email, payload content) and
deterministic cardinality bounds (non-empty non-default `service.name`;
≤16 datapoint attributes; guarded value lengths) **before export**. Producers
remain responsible for privacy at source; the platform boundary is the last
line, not the first. Exact global distinct-series prediction is out of scope —
deterministic per-datapoint bounds plus backend active-series monitoring are
the enforcement mechanism.

### V. Resource Protection Ordering
Every pipeline applies `memory_limiter` **first** and `batch` **last**; load is
shed before expensive processing rather than after. The deployed gateway runs
at most one instance and must survive its own memory policy without container
OOM (SC-003).

### VI. Single Backend, No Fan-Out
Deployed telemetry exports to **exactly one** backend destination (free-tier
Grafana Cloud OTLP gateway). Local development exports only to the loopback
LGTM stack in `compose.yaml`. Adding a second deployed destination is a
constitutional amendment, not a config tweak.

### VII. Zero-Cost, Plan-Safe Infrastructure
The deployed host MUST stay within always-free allotments: GCP **Cloud Run**
in an Always Free-eligible region, `max-instances=1`, `min-instances=0`, no
VM, no attached external IPv4, no GKE. Terraform modules MUST be **plan-safe
by default**: `enable_foundation` / `enable_runtime` / `enable_stack` default
to `false`, and no runtime or paid resource may be created without an operator
explicitly enabling it and supplying credentials (FR-008). Free allotments are
usage limits, not a guarantee of a zero invoice — egress to Grafana Cloud must
stay within free bounds.

### VIII. Simplicity (YAGNI)
Use the stock `otel/opentelemetry-collector-contrib` image (pinned version)
and its standard processors. No custom collector builds, no bespoke plugins,
no multi-replica tail-sampling topology, and no capability speculatively added
for producers that do not exist yet. Prefer configuration over code; prefer
one well-understood policy over per-producer special cases.

## Technology Constraints

- **Collector**: `otel/opentelemetry-collector-contrib:0.156.0` (pinned;
  upgrades are deliberate, validated changes)
- **Local stack**: Docker Compose — collector, Prometheus, Tempo, Loki,
  Grafana (LGTM), loopback-only, 7-day local retention
- **Cloud**: Terraform `hashicorp/google ~> 6.0` (Cloud Run, Artifact
  Registry, Secret Manager) and `grafana/grafana ~> 4.0` (Grafana Cloud
  stack, access policies, tokens)
- **Scripts**: PowerShell (`scripts/*.ps1`) — Windows-first operator tooling
- **Secrets**: never committed; `.env` (gitignored) locally, Secret Manager in
  cloud; write-only scoped tokens toward Grafana Cloud

## Ownership Boundary (Cross-Project)

| Concern | Owner |
|---------|-------|
| Collector runtime, admission policy, sanitation, batching | **This project** |
| GCP host, Grafana Cloud stack, ingest/backend credentials | **This project** |
| Platform self-telemetry rules/alerts (`monitoring/platform-rules.yml`) | **This project** |
| Producer instrumentation, privacy at source | Producer application |
| Producer SLOs, recording rules, dashboards, alerts | Producer application |
| Producer Grafana provisioning (with platform-issued scoped tokens) | Producer application |

The versioned contract binding producers is
`contracts/public/otel-ingest/`. Producers consume a released version from
their own repositories; they never consume this project's feature specs.
`specs/NNN-*/contracts/` remain internal design artifacts. In particular,
`backend-export.md` governs the platform-to-Grafana runtime edge and is not a
producer contract. This project never imports producer spec artifacts as
normative inputs.

## Quality Gates

This repository has **no domain-compiler pipeline** (no `npm run domain:*`
scripts — those belong to the agentic-foundation repo). Where a Spec-Kit skill
or template references semantic extraction / `domain:check` gates, substitute
the configuration-verification gates below; this constitution has precedence.

| Stage | Gate | Command |
|-------|------|---------|
| Spec | Manual review: Summary, Domain Mapping, `INV-COL-*`, Saga present; neutrality (Principle II) upheld | editorial |
| Public contract | Package shape, version consistency, links, and required normative sections | `scripts/check-public-contract.ps1` |
| Config | Compose + collector config validate | `scripts/validate.ps1` (compose config + collector `validate` dry-run) |
| Infra | Plan-safe Terraform validation, creation flags off | `terraform validate` in `infra/gcp` and `infra/grafana-cloud` |
| Policy | Acceptance fixtures: valid metric exported; missing/default `service.name`, >16 attributes, forbidden identity, oversized values all dropped | `scripts/test-metric-policy.ps1` |
| Runtime | Local five-service health (collector, Prometheus, Tempo, Loki, Grafana) | `scripts/validate.ps1` post-start checks |

All six gates MUST pass from a clean checkout before merge (SC-005). Policy
changes to `collector/config.yaml` REQUIRE a corresponding fixture in
`scripts/test-metric-policy.ps1` and a compatibility review of the public data
contract. Every documented class of filter behavior is proven by acceptance
test, not assumed (INV-COL-007).

## Artifact Precedence (highest wins on conflict)

| Order | Artifact | Owns |
|-------|----------|------|
| 1 | `constitution.md` | Governance, ownership boundary, gates |
| 2 | `contracts/public/<name>/` | Versioned externally observable producer contract |
| 3 | `specs/NNN-*/spec.md` | Internal domain theory — FR/SC, `INV-COL-*`, Saga |
| 4 | `specs/NNN-*/plan.md`, `research.md`, `contracts/` | Internal technical approach and design contracts |
| 5 | `collector/`, `infra/`, `compose.yaml`, `scripts/` | Implementation and executable evidence |

When internal theory conflicts with a published producer promise, the public
contract governs compatibility until a properly versioned release changes it.
As-built configuration is convergence input only.

## Governance

Amendments to this constitution require a version bump (semver: MAJOR for
principle removal/redefinition, MINOR for new principle or section, PATCH for
clarification) and a Sync Impact Report comment at the top of this file.
Changing the single-backend rule (Principle VI), the zero-cost host (Principle
VII), application neutrality (Principle II), or the public-contract boundary
(Principle III) is MAJOR. Templates in
`.specify/templates/` stay generic; project specifics live here and in
`specs/`.

**Version**: 1.1.0 | **Ratified**: 2026-07-18 | **Last Amended**: 2026-07-19
