# Quickstart

## Validate without cloud credentials

```powershell
Copy-Item .env.example .env
pwsh scripts/check-public-contract.ps1
pwsh scripts/validate.ps1

cd infra/grafana-cloud
terraform init
terraform validate
terraform plan

cd ../gcp
terraform init
terraform validate
```

## Local policy acceptance

Requires [k3d](https://k3d.io/) and `kubectl`. `local-up.ps1` stops Compose and
starts the k3s stack on ports 4318, 13133, and 3002:

```powershell
pwsh scripts/local-up.ps1
pwsh scripts/run-e2e-local.ps1
```

Equivalent individual gates (constitution wrappers):

```powershell
pwsh scripts/validate.ps1 -PostStart
pwsh scripts/test-metric-policy.ps1
pwsh scripts/test-signal-canary.ps1
pwsh scripts/test-memory-load.ps1
```

Expected: all five services are healthy; one valid metric is exported and
eight invalid fixtures (missing/default/oversized service identity, excessive
resource or datapoint attributes, datapoint or resource identity, and an
oversized guarded value) are absent.
Collector accepted/sent counters support aggregate drop inference. The signal
canary confirms traces and logs reach the backend with all sensitive
attributes removed, and the memory/load test confirms the collector survives
sustained load without OOM or restart.

## Producer integration

Producer applications pin
`contracts/public/otel-ingest@1.0.1` (release tag
`contracts/otel-ingest/v1.0.1`) and configure against its API and data
contracts. They MUST NOT import this repository's `specs/` or implementation
files.

## Cloud

1. Apply `infra/grafana-cloud` with `enable_stack=true`.
2. Apply `infra/gcp` with `enable_foundation=true` to create Artifact Registry.
3. Authenticate Docker to the regional registry, build this repository's
   `Dockerfile`, tag with an immutable version, and push.
4. Set `collector_image` to that immutable URI, set `enable_runtime=true`, and
   apply the runtime.
5. Configure each producer using `producer_environment_hint`.

Never commit `.tfvars`, state, `.env`, or tokens.

## Cloud provisioning (scripted)

Create local tfvars (gitignored) and run phases after replacing placeholders:

```powershell
# 1) Edit infra/grafana-cloud/terraform.tfvars — set cloud_access_policy_token
# 2) Edit infra/gcp/terraform.tfvars — set project_id
pwsh scripts/provision-cloud.ps1 -Phase check

# Plan or apply in order:
pwsh scripts/provision-cloud.ps1 -Phase grafana        # stack + OTLP credentials
pwsh scripts/provision-cloud.ps1 -Phase gcp-foundation # Artifact Registry + APIs
pwsh scripts/provision-cloud.ps1 -Phase image          # docker build + push
pwsh scripts/provision-cloud.ps1 -Phase gcp-runtime    # Cloud Run + secrets
pwsh scripts/provision-cloud.ps1 -Phase rules          # platform recording/alerts
pwsh scripts/provision-cloud.ps1 -Phase e2e-cloud      # Cloud Run + Grafana LGTM E2E

# Or plan-only:
pwsh scripts/provision-cloud.ps1 -Phase all -PlanOnly
```

The script auto-generates a local `ingest_bearer_token` and syncs Grafana OTLP outputs into `infra/gcp/terraform.tfvars` after the Grafana apply.

