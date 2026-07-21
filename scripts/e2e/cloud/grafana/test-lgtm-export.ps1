[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$CloudRunUri,
  [Parameter(Mandatory)]
  [string]$IngestBearerToken,
  [string]$GrafanaStackUrl,
  [string]$GrafanaApiToken,
  [string]$GrafanaPromUrl,
  [string]$GrafanaPromUser,
  [string]$GrafanaLogsUrl,
  [string]$GrafanaTempoUrl,
  [string]$GrafanaQueryToken,
  [hashtable]$IngestContext
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\lib\Otlp.ps1')
. (Join-Path $PSScriptRoot '..\..\lib\Retry.ps1')
. (Join-Path $PSScriptRoot '..\..\lib\GrafanaQuery.ps1')

$ctx = if ($IngestContext) {
  $IngestContext
}
else {
  $marker = New-OtlpMarker 'cloud-grafana'
  Send-OtlpSignals `
    -BaseUrl $CloudRunUri.TrimEnd('/') `
    -BearerToken $IngestBearerToken `
    -Marker $marker `
    -MetricName 'cloud.e2e.export'
}

$marker = $ctx.Marker
$traceId = $ctx.TraceId
Write-Host "Grafana Cloud LGTM E2E: verifying marker $marker"

$useHttpApi = Test-UsesGrafanaHttpApi $GrafanaQueryToken
if ($useHttpApi) {
  if ([string]::IsNullOrWhiteSpace($GrafanaStackUrl) -or [string]::IsNullOrWhiteSpace($GrafanaApiToken)) {
    throw 'Grafana HTTP API verification requires GrafanaStackUrl and GrafanaApiToken (or e2e_query_token for direct LGTM URLs).'
  }
  Write-Host 'Using Grafana HTTP API (stack URL + API token) for LGTM query verification.'

  Invoke-Until -Label 'Prometheus export' -Attempts 18 -DelaySeconds 10 -Action {
    [pscustomobject]@{ Ok = (Test-GrafanaPromMetric $GrafanaStackUrl $GrafanaApiToken 'cloud_e2e_export_total{service_name="e2e-metrics"}' 'e2e-metrics') }
  } -Success {
    param($r) $r.Ok
  } | Out-Null
  Write-Host 'Prometheus: cloud_e2e_export_total found with marker.'

  $lokiExpr = "{service_name=`"e2e-logs`"} |= `"$marker`""
  Invoke-Until -Label 'Loki export' -Attempts 18 -DelaySeconds 10 -Action {
    [pscustomobject]@{ Ok = (Test-GrafanaLokiMarker $GrafanaStackUrl $GrafanaApiToken $lokiExpr $marker) }
  } -Success {
    param($r) $r.Ok
  } | Out-Null
  Write-Host 'Loki: log line found with marker.'

  Invoke-Until -Label 'Tempo export' -Attempts 18 -DelaySeconds 10 -Action {
    [pscustomobject]@{ Ok = (Test-GrafanaTempoTrace $GrafanaStackUrl $GrafanaApiToken $traceId $marker) }
  } -Success {
    param($r) $r.Ok
  } | Out-Null
  Write-Host 'Tempo: trace found with marker.'
}
else {
  $promBase = $GrafanaPromUrl.TrimEnd('/')
  $logsBase = $GrafanaLogsUrl.TrimEnd('/')
  $tempoBase = $GrafanaTempoUrl.TrimEnd('/')

  $promQuery = [uri]::EscapeDataString('cloud_e2e_export_total{service_name="e2e-metrics"}')
  $promUrl = "$promBase/api/prom/api/v1/query?query=$promQuery"

  $nowMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $startNs = ($nowMs - 600000) * 1000000
  $endNs = ($nowMs + 120000) * 1000000
  $lokiExpr = [uri]::EscapeDataString("{service_name=`"e2e-logs`"} |= `"$marker`"")
  $lokiUrl = "$logsBase/loki/api/v1/query_range?query=$lokiExpr&start=$startNs&end=$endNs&limit=50"
  $tempoUrl = "$tempoBase/api/traces/$traceId"

  Invoke-Until -Label 'Prometheus export' -Attempts 18 -DelaySeconds 10 -Action {
    Invoke-GrafanaGet $promUrl $GrafanaPromUser $GrafanaQueryToken
  } -Success {
    param($r)
    $r.StatusCode -eq 200 -and $r.Content -match 'cloud_e2e_export_total' -and $r.Content -match 'e2e-metrics'
  } | Out-Null
  Write-Host 'Prometheus: cloud_e2e_export_total found with marker.'

  Invoke-Until -Label 'Loki export' -Attempts 18 -DelaySeconds 10 -Action {
    Invoke-GrafanaGet $lokiUrl $GrafanaPromUser $GrafanaQueryToken
  } -Success {
    param($r)
    $r.StatusCode -eq 200 -and $r.Content -match [regex]::Escape($marker)
  } | Out-Null
  Write-Host 'Loki: log line found with marker.'

  Invoke-Until -Label 'Tempo export' -Attempts 18 -DelaySeconds 10 -Action {
    Invoke-GrafanaGet $tempoUrl $GrafanaPromUser $GrafanaQueryToken
  } -Success {
    param($r)
    $r.StatusCode -eq 200 -and $r.Content -match [regex]::Escape($marker)
  } | Out-Null
  Write-Host 'Tempo: trace found with marker.'
}

Write-Host 'Grafana Cloud LGTM E2E passed: metrics, logs, and traces queryable after Cloud Run export.'
