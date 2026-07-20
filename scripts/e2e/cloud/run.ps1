[CmdletBinding()]
param(
  [switch]$SkipGcp,
  [switch]$SkipGrafana
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\lib\CloudConfig.ps1')

$config = Resolve-CloudE2EConfig
Test-CloudE2EConfig $config -RequireGrafanaQuery:(-not $SkipGrafana)

$ingestCtx = $null
if (-not $SkipGcp) {
  $ingestCtx = & (Join-Path $PSScriptRoot 'gcp\test-cloud-run-ingest.ps1') `
    -CloudRunUri $config.CloudRunUri `
    -IngestBearerToken $config.IngestBearerToken
}

if (-not $SkipGrafana) {
  & (Join-Path $PSScriptRoot 'grafana\test-lgtm-export.ps1') `
    -CloudRunUri $config.CloudRunUri `
    -IngestBearerToken $config.IngestBearerToken `
    -GrafanaPromUrl $config.GrafanaPromUrl `
    -GrafanaPromUser $config.GrafanaPromUser `
    -GrafanaLogsUrl $config.GrafanaLogsUrl `
    -GrafanaTempoUrl $config.GrafanaTempoUrl `
    -GrafanaQueryToken $config.GrafanaQueryToken `
    -IngestContext $ingestCtx
}

Write-Host 'Cloud E2E suite passed (GCP Cloud Run + Grafana Cloud LGTM).'
