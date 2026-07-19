[CmdletBinding()]
param([switch]$PostStart)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')

Push-Location $root
try {
  & (Join-Path $PSScriptRoot 'check-public-contract.ps1')

  docker compose config --quiet
  if ($LASTEXITCODE -ne 0) { throw 'Compose configuration is invalid.' }

  docker compose run --rm --no-deps otel-collector validate `
    --config=/etc/otelcol-contrib/config.yaml `
    --config=/etc/otelcol-contrib/local-overrides.yaml
  if ($LASTEXITCODE -ne 0) { throw 'Collector configuration is invalid.' }

  if (-not $PostStart) {
    Write-Host 'Configuration is valid.'
    exit 0
  }

  foreach ($service in @('otel-collector', 'prometheus', 'tempo', 'loki', 'grafana')) {
    $id = docker compose ps --quiet $service
    if (-not $id) { throw "$service has no running container." }
    $state = docker inspect --format '{{.State.Running}} {{if .State.Health}}{{.State.Health.Status}}{{end}}' $id
    if (-not $state.StartsWith('true') -or $state.EndsWith('unhealthy')) {
      throw "$service is not healthy: $state"
    }
    Write-Host "$service`: $state"
  }

  $collector = Invoke-RestMethod http://127.0.0.1:13133/ -TimeoutSec 5
  if ($collector.status -ne 'Server available') {
    throw 'Collector health endpoint is not available.'
  }
  $grafana = Invoke-RestMethod http://127.0.0.1:3002/api/health -TimeoutSec 5
  if ($grafana.database -ne 'ok') { throw 'Grafana database is not healthy.' }

  Write-Host 'Local telemetry platform is healthy.'
}
finally {
  Pop-Location
}

