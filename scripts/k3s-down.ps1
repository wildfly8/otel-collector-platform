[CmdletBinding()]
param(
  [string]$ClusterName = 'otel-platform-k3s',
  [switch]$DeleteCluster,
  [switch]$KeepCluster
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$k3sDir = Join-Path $root 'k3s'

if (Get-Command kubectl -ErrorAction SilentlyContinue) {
  kubectl delete -k $k3sDir --ignore-not-found=true
}

if ($DeleteCluster -or -not $KeepCluster) {
  $deleted = $false
  if (Get-Command k3d -ErrorAction SilentlyContinue) {
    k3d cluster delete $ClusterName 2>$null
    $deleted = $true
    Write-Host "Deleted k3d cluster '$ClusterName'."
  }
  elseif (Get-Command docker -ErrorAction SilentlyContinue) {
    $prefix = "k3d-$ClusterName"
    $containers = @(docker ps -a --filter "name=$prefix" --format '{{.Names}}' 2>$null)
    if ($containers.Count -gt 0) {
      docker rm -f @containers 2>$null | Out-Null
      docker network rm $prefix 2>$null | Out-Null
      docker volume rm "$prefix-images" 2>$null | Out-Null
      $deleted = $true
      Write-Host "Removed k3d cluster '$ClusterName' via Docker (k3d CLI not on PATH)."
    }
  }
  if (-not $deleted) {
    Write-Host "No k3d cluster '$ClusterName' found to delete."
  }
}
else {
  Write-Host "Removed workloads; kept k3d cluster '$ClusterName' (use -DeleteCluster to remove it)."
}
