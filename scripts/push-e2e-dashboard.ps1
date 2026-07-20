[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$grafanaDir = Join-Path $root 'infra\grafana-cloud'
$source = Join-Path $root 'monitoring\e2e-dashboard.json'

. (Join-Path $PSScriptRoot 'e2e\lib\CloudConfig.ps1')

$stackUrl = $env:GRAFANA_STACK_URL
if ([string]::IsNullOrWhiteSpace($stackUrl)) {
  $stackUrl = Get-TerraformOutput $grafanaDir 'stack_url'
}
$apiToken = $env:GRAFANA_CLOUD_API_TOKEN
if ([string]::IsNullOrWhiteSpace($apiToken)) {
  $apiToken = Get-TerraformOutput $grafanaDir 'producer_provisioner_token'
}

if ([string]::IsNullOrWhiteSpace($stackUrl) -or [string]::IsNullOrWhiteSpace($apiToken)) {
  if ($DryRun) {
    Write-Host '[dry-run] Missing GRAFANA_STACK_URL or GRAFANA_CLOUD_API_TOKEN; would load from terraform outputs.'
    exit 0
  }
  throw 'Set GRAFANA_STACK_URL and GRAFANA_CLOUD_API_TOKEN, or apply infra/grafana-cloud (producer_provisioner_token).'
}

$base = $stackUrl.TrimEnd('/')
$headers = @{
  Authorization = "Bearer $apiToken"
  Accept        = 'application/json'
}

function Invoke-GrafanaApiGet([string]$Path) {
  $uri = "$base$Path"
  if ($DryRun) {
    Write-Host "[dry-run] GET $uri"
    return $null
  }
  $raw = Invoke-WebRequest -Method Get -Uri $uri -Headers $headers -UseBasicParsing
  if ([string]::IsNullOrWhiteSpace($raw.Content)) { return $null }
  return $raw.Content | ConvertFrom-Json
}

function Invoke-GrafanaApiPost([string]$Path, [string]$Body) {
  $uri = "$base$Path"
  if ($DryRun) {
    Write-Host "[dry-run] POST $uri"
    return $null
  }
  $raw = Invoke-WebRequest `
    -Method Post `
    -Uri $uri `
    -Headers $headers `
    -ContentType 'application/json' `
    -Body $Body `
    -UseBasicParsing
  if ([string]::IsNullOrWhiteSpace($raw.Content)) { return $null }
  return $raw.Content | ConvertFrom-Json
}

function Get-StackDataSourceUid([string]$Kind) {
  $items = Invoke-GrafanaApiGet '/api/datasources'
  if ($DryRun) { return "${Kind}-dry-run" }
  $slug = ($base -replace '^https://', '').Split('.')[0]
  $expectedName = switch ($Kind) {
    'prometheus' { "grafanacloud-$slug-prom" }
    'loki' { "grafanacloud-$slug-logs" }
    'tempo' { "grafanacloud-$slug-traces" }
    default { throw "Unknown datasource kind '$Kind'." }
  }
  $match = @($items | Where-Object { $_.name -eq $expectedName })[0]
  if (-not $match) {
    $match = @($items | Where-Object {
        $_.type -eq $Kind -and $_.name -notmatch 'usage|insights|alert'
      } | Sort-Object { $_.name -like "grafanacloud-$slug-*" } -Descending)[0]
  }
  if (-not $match) { throw "No Grafana '$Kind' datasource found on $base (expected '$expectedName')." }
  Write-Host "Using $Kind datasource: $($match.name) ($($match.uid))"
  return $match.uid
}

$promUid = Get-StackDataSourceUid 'prometheus'
$lokiUid = Get-StackDataSourceUid 'loki'
$tempoUid = Get-StackDataSourceUid 'tempo'

$dashboardJson = Get-Content -LiteralPath $source -Raw
$dashboardJson = $dashboardJson.Replace('PROM_DS_UID', $promUid)
$dashboardJson = $dashboardJson.Replace('LOKI_DS_UID', $lokiUid)
$dashboardJson = $dashboardJson.Replace('TEMPO_DS_UID', $tempoUid)
$dashboardJson = ($dashboardJson -replace '(?m)^\s*"id"\s*:\s*null,\s*\r?\n', '')

$folderUid = 'platform'
if (-not $DryRun) {
  $folderExists = $false
  try {
    Invoke-GrafanaApiGet "/api/folders/$folderUid" | Out-Null
    $folderExists = $true
  }
  catch {
    $folderExists = $false
  }
  if (-not $folderExists) {
    $folderBody = (@{ uid = $folderUid; title = 'Platform' } | ConvertTo-Json -Compress)
    Invoke-GrafanaApiPost '/api/folders' $folderBody | Out-Null
    Write-Host "Created Grafana folder 'Platform' (uid=$folderUid)."
  }
}

$dashboardBody = $dashboardJson.Trim()
if ($dashboardBody.EndsWith(',')) {
  $dashboardBody = $dashboardBody.Substring(0, $dashboardBody.Length - 1)
}
$payload = '{"dashboard":' + $dashboardBody + ',"folderUid":"' + $folderUid + '","overwrite":true,"message":"push-e2e-dashboard.ps1"}'

if ($DryRun) {
  Write-Host "[dry-run] POST $base/api/dashboards/db (uid platform-e2e-cloud)"
  Write-Host "Payload bytes: $([Text.Encoding]::UTF8.GetByteCount($payload))"
  exit 0
}

$result = Invoke-GrafanaApiPost '/api/dashboards/db' $payload
$url = if ($result.url) { "$base$($result.url)" } else { "$base/d/platform-e2e-cloud" }
Write-Host "Published E2E dashboard: $url"
