# Shared helpers for local k3s/k3d runtime (default local stack).

$script:LocalK8sNamespace = if ($env:OTEL_K8S_NAMESPACE) {
  $env:OTEL_K8S_NAMESPACE
} else {
  'otel-platform'
}

$script:LocalOtlpUrl = if ($env:OTEL_COLLECTOR_OTLP_URL) {
  $env:OTEL_COLLECTOR_OTLP_URL.TrimEnd('/')
} else {
  'http://127.0.0.1:4318'
}

$script:LocalHealthUrl = if ($env:OTEL_COLLECTOR_HEALTH_URL) {
  $env:OTEL_COLLECTOR_HEALTH_URL.TrimEnd('/')
} else {
  'http://127.0.0.1:13133'
}

$script:LocalGrafanaUrl = if ($env:OTEL_GRAFANA_URL) {
  $env:OTEL_GRAFANA_URL.TrimEnd('/')
} else {
  'http://127.0.0.1:3002'
}

$script:LocalBearerToken = if ($env:OTEL_COLLECTOR_BEARER_TOKEN) {
  $env:OTEL_COLLECTOR_BEARER_TOKEN
} else {
  'local-platform-token-32-characters'
}

function Assert-LocalK8sReady {
  if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    throw 'kubectl is required for the local k3s stack.'
  }
  $ns = kubectl get namespace $script:LocalK8sNamespace -o name 2>$null
  if ($LASTEXITCODE -ne 0) {
    throw "Namespace '$($script:LocalK8sNamespace)' is missing. Run scripts/local-up.ps1 first."
  }
}

function Invoke-InClusterHttp([string]$Url) {
  Assert-LocalK8sReady
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'SilentlyContinue'
  $out = kubectl -n $script:LocalK8sNamespace exec deploy/prometheus -- wget -qO- $Url 2>$null
  $ErrorActionPreference = $prev
  if ($LASTEXITCODE -ne 0) { return '' }
  return ($out -join "`n")
}

function Get-CollectorPod {
  Assert-LocalK8sReady
  $json = kubectl -n $script:LocalK8sNamespace get pods -l app=otel-collector -o json | ConvertFrom-Json
  $pod = @($json.items | Where-Object { $_.status.phase -eq 'Running' })[0]
  if (-not $pod) {
    $pod = @($json.items)[0]
  }
  if (-not $pod) { throw 'otel-collector pod was not found in the local k3s namespace.' }
  return $pod
}

function Get-CollectorPodStatus {
  $pod = Get-CollectorPod
  $container = @($pod.status.containerStatuses | Where-Object { $_.name -eq 'otel-collector' })[0]
  if (-not $container) {
    throw 'otel-collector container status is unavailable.'
  }
  $oom = $false
  if ($container.lastState.terminated.reason -eq 'OOMKilled') { $oom = $true }
  return [pscustomobject]@{
    Name         = $pod.metadata.name
    Running      = ($pod.status.phase -eq 'Running' -and $container.ready)
    RestartCount = [int]$container.restartCount
    OOMKilled    = $oom
  }
}

function Wait-LocalDeployment([string]$Name, [int]$TimeoutSeconds = 180) {
  Assert-LocalK8sReady
  kubectl -n $script:LocalK8sNamespace rollout status "deployment/$Name" --timeout="${TimeoutSeconds}s"
  if ($LASTEXITCODE -ne 0) {
    throw "Deployment '$Name' did not become ready within ${TimeoutSeconds}s."
  }
}
