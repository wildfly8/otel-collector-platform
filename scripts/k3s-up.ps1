[CmdletBinding()]
param(
  [string]$ClusterName = 'otel-platform-k3s',
  [switch]$RecreateCluster
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$k3sDir = Join-Path $root 'k3s'

if (-not (Get-Command k3d -ErrorAction SilentlyContinue)) {
  throw @'
k3d is required on Windows (k3s runs inside Docker).
Install: https://k3d.io/stable/#installation
Also ensure kubectl is on PATH (k3d includes kubeconfig merge).
'@
}

function Initialize-K3dKubeconfig([string]$Name) {
  $serverLb = "k3d-$Name-serverlb"
  $mapping = docker port $serverLb 6443/tcp 2>$null
  if (-not $mapping) {
    throw "Could not resolve API port for $serverLb. Is the cluster running?"
  }
  $apiPort = ($mapping -split ':')[-1]
  k3d kubeconfig merge $Name --kubeconfig-merge-default --kubeconfig-switch-context
  kubectl config set-cluster "k3d-$Name" --server="https://127.0.0.1:$apiPort"
}

$exists = @(k3d cluster list -o json | ConvertFrom-Json | Where-Object { $_.name -eq $ClusterName })
if ($RecreateCluster -and $exists.Count -gt 0) {
  k3d cluster delete $ClusterName
  $exists = @()
}

if ($exists.Count -eq 0) {
  Write-Host "Creating k3d cluster '$ClusterName'..."
  k3d cluster create $ClusterName `
    --port "4318:4318@loadbalancer" `
    --port "13133:13133@loadbalancer" `
    --port "3002:3000@loadbalancer" `
    --wait
  Initialize-K3dKubeconfig $ClusterName
}
else {
  Write-Host "Reusing k3d cluster '$ClusterName'."
  Initialize-K3dKubeconfig $ClusterName
}

Write-Host 'Waiting for Kubernetes API...'
$ready = $false
for ($i = 1; $i -le 30; $i++) {
  kubectl cluster-info 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { $ready = $true; break }
  Start-Sleep -Seconds 2
}
if (-not $ready) { throw 'Kubernetes API did not become reachable.' }

Write-Host 'Applying manifests (kustomize)...'
$manifest = kubectl kustomize $k3sDir --load-restrictor LoadRestrictionsNone
if ($LASTEXITCODE -ne 0) { throw 'kustomize build failed.' }
$manifest | kubectl apply -f -
if ($LASTEXITCODE -ne 0) { throw 'kubectl apply failed.' }

Write-Host 'Waiting for deployments...'
foreach ($deploy in @('prometheus', 'tempo', 'loki', 'grafana', 'otel-collector')) {
  kubectl -n otel-platform rollout status "deployment/$deploy" --timeout=180s
  if ($LASTEXITCODE -ne 0) { throw "Deployment '$deploy' did not become ready." }
}

Write-Host ''
Write-Host 'Local k3s stack is up:'
Write-Host '  OTLP/HTTP:  http://127.0.0.1:4318'
Write-Host '  Health:     http://127.0.0.1:13133'
Write-Host '  Grafana:    http://127.0.0.1:3002  (admin / admin)'
Write-Host ''
Write-Host 'Teardown: pwsh scripts/local-down.ps1'
