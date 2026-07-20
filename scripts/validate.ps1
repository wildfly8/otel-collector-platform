[CmdletBinding()]
param([switch]$PostStart)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$collectorImage = 'otel/opentelemetry-collector-contrib:0.156.0'

. (Join-Path $PSScriptRoot 'e2e\lib\LocalRuntime.ps1')

Push-Location $root
try {
  & (Join-Path $PSScriptRoot 'check-public-contract.ps1')

  kubectl kustomize k3s --load-restrictor LoadRestrictionsNone | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'k3s kustomize build is invalid.' }

  docker run --rm `
    -e OTEL_COLLECTOR_BEARER_TOKEN=local-platform-token-32-characters `
    -e GRAFANA_CLOUD_OTLP_ENDPOINT=https://unused.invalid/otlp `
    -e GRAFANA_CLOUD_INSTANCE_ID=unused `
    -e GRAFANA_CLOUD_TOKEN=unused `
    -e GRAFANA_CLOUD_AUTH_HEADER='Basic dW51c2VkOnVudXNlZA==' `
    -v "${root}/collector/config.yaml:/etc/otelcol-contrib/config.yaml:ro" `
    -v "${root}/collector/local-overrides.yaml:/etc/otelcol-contrib/local-overrides.yaml:ro" `
    $collectorImage validate `
    --config=/etc/otelcol-contrib/config.yaml `
    --config=/etc/otelcol-contrib/local-overrides.yaml
  if ($LASTEXITCODE -ne 0) { throw 'Collector configuration is invalid.' }

  if (-not $PostStart) {
    Write-Host 'Configuration is valid.'
    exit 0
  }

  Assert-LocalK8sReady
  foreach ($deploy in @('otel-collector', 'prometheus', 'tempo', 'loki', 'grafana')) {
    Wait-LocalDeployment $deploy
    Write-Host "$deploy`: ready"
  }

  $collector = Invoke-RestMethod "$($script:LocalHealthUrl)/" -TimeoutSec 10
  if ($collector.status -ne 'Server available') {
    throw 'Collector health endpoint is not available.'
  }
  $grafana = Invoke-RestMethod "$($script:LocalGrafanaUrl)/api/health" -TimeoutSec 10
  if ($grafana.database -ne 'ok') { throw 'Grafana database is not healthy.' }

  Write-Host 'Local telemetry platform is healthy (k3s).'
}
finally {
  Pop-Location
}
