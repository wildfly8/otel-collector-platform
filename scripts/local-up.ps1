[CmdletBinding()]
param(
  [switch]$RecreateCluster
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')

Push-Location $root
try {
  if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Host 'Stopping Docker Compose stack (if running)...'
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    docker compose down --remove-orphans *> $null
    $ErrorActionPreference = $prev
  }
}
finally {
  Pop-Location
}

& (Join-Path $PSScriptRoot 'k3s-up.ps1') -RecreateCluster:$RecreateCluster
