# Shared OTLP/JSON helpers for local and cloud E2E tests.

function New-OtlpAttr([string]$Key, [string]$Value) {
  return @{ key = $Key; value = @{ stringValue = $Value } }
}

function New-OtlpMarker([string]$Prefix = 'e2e') {
  return "$Prefix-$([guid]::NewGuid().ToString('N'))"
}

function New-OtlpTraceId {
  return -join (1..32 | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
}

function New-OtlpSpanId {
  return -join (1..16 | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
}

function New-OtlpMetricBody(
  [string]$ServiceName,
  [string]$MetricName,
  [string]$Marker,
  [string]$AsInt = '1'
) {
  $nowNs = ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000000).ToString()
  return @{
    resourceMetrics = @(@{
        resource     = @{ attributes = @(
            (New-OtlpAttr 'service.name' $ServiceName),
            (New-OtlpAttr 'e2e.marker' $Marker)
          ) }
        scopeMetrics = @(@{
            scope   = @{ name = 'platform-e2e' }
            metrics = @(@{
                name = $MetricName
                sum  = @{
                  aggregationTemporality = 2
                  isMonotonic          = $true
                  dataPoints           = @(@{
                      asInt          = $AsInt
                      timeUnixNano   = $nowNs
                      attributes     = @((New-OtlpAttr 'e2e.marker' $Marker))
                    })
                }
              })
          })
      })
  }
}

function New-OtlpTraceBody(
  [string]$ServiceName,
  [string]$Marker,
  [string]$TraceId,
  [string]$SpanId
) {
  $nowNs = ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000000).ToString()
  return @{
    resourceSpans = @(@{
        resource   = @{ attributes = @(
            (New-OtlpAttr 'service.name' $ServiceName),
            (New-OtlpAttr 'e2e.marker' $Marker)
          ) }
        scopeSpans = @(@{
            scope = @{ name = 'platform-e2e' }
            spans = @(@{
                traceId           = $TraceId
                spanId            = $SpanId
                name              = 'e2e-span'
                kind              = 1
                startTimeUnixNano = $nowNs
                endTimeUnixNano   = $nowNs
                attributes        = @((New-OtlpAttr 'e2e.marker' $Marker))
              })
          })
      })
  }
}

function New-OtlpLogBody([string]$ServiceName, [string]$Marker) {
  $nowNs = ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() * 1000000).ToString()
  return @{
    resourceLogs = @(@{
        resource  = @{ attributes = @(
            (New-OtlpAttr 'service.name' $ServiceName),
            (New-OtlpAttr 'e2e.marker' $Marker)
          ) }
        scopeLogs = @(@{
            scope      = @{ name = 'platform-e2e' }
            logRecords = @(@{
                timeUnixNano   = $nowNs
                severityNumber = 9
                severityText   = 'INFO'
                body           = @{ stringValue = "e2e log $Marker" }
                attributes     = @((New-OtlpAttr 'e2e.marker' $Marker))
              })
          })
      })
  }
}

function Invoke-OtlpJson(
  [string]$BaseUrl,
  [string]$Path,
  [string]$BearerToken,
  [hashtable]$Body
) {
  $base = $BaseUrl.TrimEnd('/')
  $json = $Body | ConvertTo-Json -Depth 40 -Compress
  return Invoke-WebRequest `
    -Method Post `
    -Uri "$base/$Path" `
    -Headers @{ Authorization = "Bearer $BearerToken" } `
    -ContentType 'application/json' `
    -Body $json `
    -UseBasicParsing
}

function Send-OtlpSignals(
  [string]$BaseUrl,
  [string]$BearerToken,
  [string]$Marker,
  [string]$MetricsService = 'e2e-metrics',
  [string]$TracesService = 'e2e-traces',
  [string]$LogsService = 'e2e-logs',
  [string]$MetricName = 'cloud.e2e.metric',
  [string]$MetricValue = '1',
  [string]$TraceId = $(New-OtlpTraceId),
  [string]$SpanId = $(New-OtlpSpanId)
) {
  $metric = Invoke-OtlpJson $BaseUrl 'v1/metrics' $BearerToken (
    New-OtlpMetricBody $MetricsService $MetricName $Marker $MetricValue
  )
  if ($metric.StatusCode -lt 200 -or $metric.StatusCode -ge 300) {
    throw "Metrics ingest failed: HTTP $($metric.StatusCode)"
  }

  $trace = Invoke-OtlpJson $BaseUrl 'v1/traces' $BearerToken (
    New-OtlpTraceBody $TracesService $Marker $TraceId $SpanId
  )
  if ($trace.StatusCode -lt 200 -or $trace.StatusCode -ge 300) {
    throw "Traces ingest failed: HTTP $($trace.StatusCode)"
  }

  $log = Invoke-OtlpJson $BaseUrl 'v1/logs' $BearerToken (
    New-OtlpLogBody $LogsService $Marker
  )
  if ($log.StatusCode -lt 200 -or $log.StatusCode -ge 300) {
    throw "Logs ingest failed: HTTP $($log.StatusCode)"
  }

  return @{
    Marker         = $Marker
    TraceId        = $TraceId
    SpanId         = $SpanId
    MetricsService = $MetricsService
    TracesService  = $TracesService
    LogsService    = $LogsService
    MetricName     = $MetricName
  }
}
