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

## Decision 7 — k3s as default local runtime

**Decision**: Use k3d/k3s (`k3s/` Kustomize manifests) as the default local
LGTM stack; keep `compose.yaml` as a legacy reference only.

**Reason**: Aligns local dev with Kubernetes service discovery (in-cluster OTLP
to Tempo/Loki/Prometheus), matches operator tooling on Windows via k3d, and
separates the platform local stack from Docker Compose–based producer apps.
`scripts/local-up.ps1` stops any repo Compose stack before starting k3d.

## Decision 8 — Memory pressure and OOM fallback

**Local (Docker Desktop / k3d)**:

1. **Primary**: `memory_limiter` is first in every pipeline (`limit_mib: 384`,
   `spike_limit_mib: 96` in `collector/config.yaml`). Under pressure the
   collector **refuses** new telemetry (SAGA-COL-001 **CG07**) before expensive
   work — producers retry with backoff.
2. **k3s cgroup**: collector pod has a **512Mi** limit (parity with Cloud Run)
   so Docker Desktop cannot let the process grow unbounded.
3. **Verification**: `scripts/e2e/local/test-memory-load.ps1` drives ~75k
   datapoints and asserts **no OOMKilled** and **no restart**.
4. **Operator fallback**: if Docker Desktop itself is memory-starved, increase
   Docker RAM or reduce concurrent workloads; platform policy cannot fix host
   OOM outside the collector pod.

**Cloud Run**:

1. **Primary**: same `memory_limiter` settings (384 + 96 MiB spike within
   **512Mi** Cloud Run limit).
2. **Shed load**: `otelcol_receiver_refused_*` counters and platform alert
   `monitoring/platform-rules.yml` surface refusals.
3. **No multi-instance fan-out**: `max-instances=1` — overload sheds at the
   gateway; producers retry.
4. **Scale-to-zero**: `min-instances=0`; in-flight batches may be lost on cold
   stop — short batch timeout (`1s`) and producer OTLP retries mitigate.
5. **Verification**: cloud ingest E2E + Grafana LGTM query E2E after export.

