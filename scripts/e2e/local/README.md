# Local E2E (k3s LGTM)

These tests exercise the collector and **local** LGTM backends in the k3d/k3s
namespace `otel-platform` (see `k3s/README.md`).

## Tests

| Script | Gate |
|--------|------|
| `test-metric-policy.ps1` | Metric admission policy (8 invalid + 1 valid) |
| `test-signal-canary.ps1` | Trace/log sanitation (INV-COL-006) |
| `test-memory-load.ps1` | Memory limiter under load (SC-003) |

`run.ps1` runs `validate.ps1 -PostStart` then all three tests.

## Runtime

Start the stack before running tests:

```powershell
pwsh scripts/local-up.ps1
pwsh scripts/run-e2e-local.ps1
```

Shared helpers live in `scripts/e2e/lib/LocalRuntime.ps1` (kubectl in-cluster
queries, default loopback URLs on ports 4318 / 13133 / 3002).
