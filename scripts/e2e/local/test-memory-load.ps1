[CmdletBinding()]
param(
  [int]$Batches = 150,
  [int]$DatapointsPerBatch = 500
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
. (Join-Path $PSScriptRoot '..\lib\LocalRuntime.ps1')

function Get-CollectorInternalMetrics {
  return Invoke-InClusterHttp 'http://otel-collector:8888/metrics'
}

function Get-AcceptedMetricPoints([string]$Metrics) {
  $sum = 0.0
  foreach ($line in ($Metrics -split "`n")) {
    if ($line -match '^otelcol_receiver_accepted_metric_points(\{[^}]*\})?\s+([0-9.eE+]+)$') {
      $sum += [double]$Matches[2]
    }
  }
  return $sum
}

Push-Location $root
try {
  $before = Get-CollectorPodStatus
  if (-not $before.Running) {
    throw "otel-collector is not running before load: $($before.Name)"
  }
  $beforeRestarts = $before.RestartCount

  $acceptedBefore = Get-AcceptedMetricPoints (Get-CollectorInternalMetrics)

  Write-Host "Applying load: $Batches batches x $DatapointsPerBatch datapoints..."
  for ($b = 0; $b -lt $Batches; $b++) {
    $dataPoints = 1..$DatapointsPerBatch | ForEach-Object {
      @{
        asInt        = '1'
        timeUnixNano = ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000000).ToString()
        attributes   = @(
          @{ key = 'http.request.method'; value = @{ stringValue = 'GET' } },
          @{ key = 'bounded.series'; value = @{ intValue = ($_ % 50).ToString() } }
        )
      }
    }
    $body = @{
      resourceMetrics = @(@{
          resource     = @{ attributes = @(@{ key = 'service.name'; value = @{ stringValue = 'load-test' } }) }
          scopeMetrics = @(@{
              scope   = @{ name = 'memory-load-test' }
              metrics = @(@{
                  name = 'platform_load_test_total'
                  sum  = @{ aggregationTemporality = 2; isMonotonic = $true; dataPoints = $dataPoints }
                })
            })
        })
    } | ConvertTo-Json -Depth 30 -Compress

    Invoke-RestMethod `
      -Method Post `
      -Uri "$($script:LocalOtlpUrl)/v1/metrics" `
      -Headers @{ Authorization = "Bearer $($script:LocalBearerToken)" } `
      -ContentType 'application/json' `
      -Body $body | Out-Null
  }

  Start-Sleep -Seconds 5

  $after = Get-CollectorPodStatus
  if (-not $after.Running) { throw "Collector is not running after load: $($after.Name)" }
  if ($after.OOMKilled) { throw 'Collector was OOM-killed under load (SC-003 violated).' }
  if ($after.RestartCount -ne $beforeRestarts) {
    throw "Collector restarted under load ($beforeRestarts -> $($after.RestartCount)); memory policy did not protect the process."
  }

  $internal = Get-CollectorInternalMetrics
  $acceptedAfter = Get-AcceptedMetricPoints $internal
  if ($acceptedAfter -le $acceptedBefore) {
    throw "Collector did not process the load (accepted metric points did not advance: $acceptedBefore -> $acceptedAfter)."
  }

  $config = Get-Content (Join-Path $root 'collector/config.yaml') -Raw
  if ($config -notmatch 'memory_limiter') { throw 'memory_limiter is absent from the collector config.' }
  $pipelines = [regex]::Matches($config, '(?m)processors:\s*\r?\n\s*\[([^\]]+)\]')
  if ($pipelines.Count -lt 3) {
    throw "Expected 3 signal pipelines with memory_limiter first, found $($pipelines.Count)."
  }
  foreach ($m in $pipelines) {
    $first = ($m.Groups[1].Value -split ',')[0].Trim()
    if ($first -ne 'memory_limiter') {
      throw "A pipeline does not apply memory_limiter first: '$($m.Groups[1].Value.Trim())'."
    }
  }
  if ($internal -notmatch 'otelcol_process_memory_rss' -and $internal -notmatch 'process_runtime') {
    throw 'Collector does not expose process memory self-telemetry needed to observe the memory policy.'
  }

  $processed = [int]($acceptedAfter - $acceptedBefore)
  Write-Host "Memory/load test passed: processed ~$processed datapoints; no OOM, no restart; memory_limiter active and observable."
}
finally {
  Pop-Location
}
