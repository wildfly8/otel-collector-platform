[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$CloudRunUri,
  [Parameter(Mandatory)]
  [string]$IngestBearerToken,
  [string]$Marker
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\..\lib\Otlp.ps1')

if ([string]::IsNullOrWhiteSpace($Marker)) {
  $Marker = New-OtlpMarker 'cloud-gcp'
}

$base = $CloudRunUri.TrimEnd('/')
Write-Host "Cloud Run ingest E2E: $base (marker $Marker)"

$ctx = Send-OtlpSignals `
  -BaseUrl $base `
  -BearerToken $IngestBearerToken `
  -Marker $Marker `
  -MetricName 'cloud.e2e.export'

Write-Host 'Cloud Run ingest E2E passed: metrics, traces, and logs accepted (HTTP 2xx).'
return $ctx
