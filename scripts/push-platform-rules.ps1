[CmdletBinding()]
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
foreach ($name in @(
  'GRAFANA_CLOUD_PROM_URL',
  'GRAFANA_CLOUD_PROM_USER',
  'GRAFANA_CLOUD_RULES_TOKEN'
)) {
  if (-not (Get-Item "Env:$name" -ErrorAction SilentlyContinue).Value) {
    if (-not $DryRun) { throw "Missing $name" }
  }
}

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$source = Join-Path $root 'monitoring\platform-rules.yml'
$lines = Get-Content $source
$groupStart = [Array]::FindIndex(
  [string[]]$lines,
  [Predicate[string]]{ param($line) $line -match '^  - name:' }
)
if ($groupStart -lt 0) { throw 'No rule group found.' }

$group = for ($i = $groupStart; $i -lt $lines.Count; $i++) {
  if ($i -eq $groupStart) {
    $lines[$i] -replace '^  - ', ''
  } else {
    $lines[$i] -replace '^    ', ''
  }
}
$body = $group -join "`n"
$base = if ($DryRun) {
  'https://prometheus.dry-run.grafana.net'
} else {
  $env:GRAFANA_CLOUD_PROM_URL.TrimEnd('/')
}
$uri = "$base/config/v1/rules/otel-collector-platform"

if ($DryRun) {
  Write-Host "[dry-run] POST $uri"
  Write-Host "Rule group bytes: $([Text.Encoding]::UTF8.GetByteCount($body))"
  exit 0
}

$pair = "$($env:GRAFANA_CLOUD_PROM_USER):$($env:GRAFANA_CLOUD_RULES_TOKEN)"
$auth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pair))
Invoke-WebRequest `
  -Method Post `
  -Uri $uri `
  -Headers @{ Authorization = "Basic $auth" } `
  -ContentType 'application/yaml' `
  -Body $body | Out-Null

Write-Host 'Published platform recording and alert rules.'

