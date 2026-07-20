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
  if (Get-Command k3d -ErrorAction SilentlyContinue) {
    k3d cluster delete $ClusterName 2>$null
    Write-Host "Deleted k3d cluster '$ClusterName'."
  }
}
else {
  Write-Host "Removed workloads; kept k3d cluster '$ClusterName' (use -DeleteCluster to remove it)."
}
