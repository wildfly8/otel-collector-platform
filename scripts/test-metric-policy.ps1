$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$token = if ($env:OTEL_COLLECTOR_BEARER_TOKEN) {
  $env:OTEL_COLLECTOR_BEARER_TOKEN
} else {
  'local-platform-token-32-characters'
}

function New-Attribute([string]$Key, [string]$Value) {
  return @{ key = $Key; value = @{ stringValue = $Value } }
}

function Send-Metric(
  [string]$Name,
  [object[]]$ResourceAttributes,
  [object[]]$DatapointAttributes
) {
  $body = @{
    resourceMetrics = @(@{
      resource = @{ attributes = $ResourceAttributes }
      scopeMetrics = @(@{
        scope = @{ name = 'platform-policy-test' }
        metrics = @(@{
          name = $Name
          sum = @{
            aggregationTemporality = 2
            isMonotonic = $true
            dataPoints = @(@{
              asInt = '1'
              timeUnixNano = ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000000).ToString()
              attributes = $DatapointAttributes
            })
          }
        })
      })
    })
  } | ConvertTo-Json -Depth 20 -Compress

  Invoke-RestMethod `
    -Method Post `
    -Uri 'http://127.0.0.1:4318/v1/metrics' `
    -Headers @{ Authorization = "Bearer $token" } `
    -ContentType 'application/json' `
    -Body $body | Out-Null
}

Push-Location $root
try {
  $service = @(New-Attribute 'service.name' 'policy-test')
  Send-Metric 'platform_policy_valid_total' $service @(
    (New-Attribute 'http.request.method' 'GET')
  )

  Send-Metric 'platform_policy_missing_service_total' @() @()
  Send-Metric 'platform_policy_unknown_service_total' @(
    (New-Attribute 'service.name' 'unknown_service:test')
  ) @()
  Send-Metric 'platform_policy_long_service_name_total' @(
    (New-Attribute 'service.name' ('s' * 65))
  ) @()

  $tooManyResourceAttributes = @(
    New-Attribute 'service.name' 'policy-test'
  ) + @(1..24 | ForEach-Object {
    New-Attribute "resource.dimension.$_" "v$_"
  })
  Send-Metric 'platform_policy_too_many_resource_attributes_total' `
    $tooManyResourceAttributes @()

  $tooMany = 1..17 | ForEach-Object {
    New-Attribute "bounded.dimension.$_" "v$_"
  }
  Send-Metric 'platform_policy_too_many_attributes_total' $service $tooMany

  Send-Metric 'platform_policy_forbidden_identity_total' $service @(
    (New-Attribute 'user.id' 'must-not-export')
  )
  Send-Metric 'platform_policy_forbidden_resource_identity_total' @(
    (New-Attribute 'service.name' 'policy-test'),
    (New-Attribute 'session.id' 'must-not-export')
  ) @()
  Send-Metric 'platform_policy_oversized_guarded_value_total' $service @(
    (New-Attribute 'http.route' ('r' * 129))
  )

  Start-Sleep -Seconds 4
  $exported = (docker compose exec --no-TTY prometheus `
    wget -qO- http://otel-collector:9464/metrics) -join "`n"
  $internal = (docker compose exec --no-TTY prometheus `
    wget -qO- http://otel-collector:8888/metrics) -join "`n"

  if ($exported -notmatch 'platform_policy_valid_total') {
    throw 'Valid metric did not reach the local exporter.'
  }
  foreach ($invalid in @(
    'platform_policy_missing_service_total',
    'platform_policy_unknown_service_total',
    'platform_policy_long_service_name_total',
    'platform_policy_too_many_resource_attributes_total',
    'platform_policy_too_many_attributes_total',
    'platform_policy_forbidden_identity_total',
    'platform_policy_forbidden_resource_identity_total',
    'platform_policy_oversized_guarded_value_total'
  )) {
    if ($exported -match $invalid) {
      throw "Rejected metric reached exporter: $invalid"
    }
  }
  if (
    $internal -notmatch 'otelcol_receiver_accepted_metric_points' -or
    $internal -notmatch 'otelcol_exporter_sent_metric_points'
  ) {
    throw 'Collector accepted/exported counters needed to infer policy drops are absent.'
  }

  Write-Host 'Metric admission policy passed: 1 valid exported, 8 invalid dropped; accepted/exported counters present.'
}
finally {
  Pop-Location
}

