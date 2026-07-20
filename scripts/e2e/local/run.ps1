[CmdletBinding()]
param(
  [switch]$SkipValidate,
  [switch]$SkipPolicy,
  [switch]$SkipCanary,
  [switch]$SkipLoad
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$scriptsRoot = Resolve-Path (Join-Path $here '..\..')

if (-not $SkipValidate) {
  & (Join-Path $scriptsRoot 'validate.ps1') -PostStart
}

if (-not $SkipPolicy) {
  & (Join-Path $here 'test-metric-policy.ps1')
}
if (-not $SkipCanary) {
  & (Join-Path $here 'test-signal-canary.ps1')
}
if (-not $SkipLoad) {
  & (Join-Path $here 'test-memory-load.ps1')
}

Write-Host 'Local E2E suite passed (k3s LGTM stack).'
