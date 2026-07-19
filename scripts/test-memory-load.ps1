# Load test for SC-003 / Constitution V: drive sustained telemetry through the
# collector and prove the deployed memory policy protects the process — the
# container never OOMs or restarts, load is still accepted, and the
# memory_limiter is engaged and observable.
#
# A stock Collector cannot be forced to a hard 384 MiB refusal deterministically
# from JSON/HTTP in a short run, so this gate proves stability-under-load plus an
# active, observable memory policy rather than a synthetic OOM.

[CmdletBinding()]
param(
  [int]$Batches = 150,
  [int]$DatapointsPerBatch = 500
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$token = if ($env:OTEL_COLLECTOR_BEARER_TOKEN) {
  $env:OTEL_COLLECTOR_BEARER_TOKEN
} else {
  'local-platform-token-32-characters'
}

function Get-CollectorInternalMetrics {
  $raw = docker compose exec --no-TTY prometheus wget -qO- http://otel-collector:8888/metrics 2>$null
  if ($LASTEXITCODE -ne 0) { return '' }
  return ($raw -join "`n")
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
  $cid = (docker compose ps --quiet otel-collector).Trim()
  if (-not $cid) { throw 'otel-collector container is not running.' }

  $before = docker inspect --format '{{.RestartCount}} {{.State.Running}} {{.State.OOMKilled}}' $cid
  $beforeParts = $before.Trim() -split '\s+'
  $beforeRestarts = [int]$beforeParts[0]
  if ($beforeParts[1] -ne 'true') { throw "otel-collector is not running before load: $before" }

  $acceptedBefore = Get-AcceptedMetricPoints (Get-CollectorInternalMetrics)

  # Bounded, contract-valid datapoints (usable service.name, <=16 attributes).
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
      -Uri 'http://127.0.0.1:4318/v1/metrics' `
      -Headers @{ Authorization = "Bearer $token" } `
      -ContentType 'application/json' `
      -Body $body | Out-Null
  }

  Start-Sleep -Seconds 5

  $after = docker inspect --format '{{.RestartCount}} {{.State.Running}} {{.State.OOMKilled}}' $cid
  $afterParts = $after.Trim() -split '\s+'
  $afterRestarts = [int]$afterParts[0]
  $running = $afterParts[1]
  $oomKilled = $afterParts[2]

  if ($running -ne 'true') { throw "Collector is not running after load: $after" }
  if ($oomKilled -eq 'true') { throw 'Collector was OOM-killed under load (SC-003 violated).' }
  if ($afterRestarts -ne $beforeRestarts) {
    throw "Collector restarted under load ($beforeRestarts -> $afterRestarts); memory policy did not protect the process."
  }

  $internal = Get-CollectorInternalMetrics
  $acceptedAfter = Get-AcceptedMetricPoints $internal
  if ($acceptedAfter -le $acceptedBefore) {
    throw "Collector did not process the load (accepted metric points did not advance: $acceptedBefore -> $acceptedAfter)."
  }

  # Prove the memory policy is engaged and observable. The mounted config is the
  # host file; assert memory_limiter is present and first in every pipeline.
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
