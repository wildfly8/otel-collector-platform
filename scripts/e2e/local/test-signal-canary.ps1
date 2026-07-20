# Canary proving INV-COL-006 / SC-004 across signals against the local LGTM stack.

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
. (Join-Path $PSScriptRoot '..\lib\LocalRuntime.ps1')

$marker = "canary-$([guid]::NewGuid().ToString('N'))"
$sentinel = "SENSITIVE-$([guid]::NewGuid().ToString('N'))"

$sensitiveResourceKeys = @('user.id', 'session.id', 'request.id', 'url.full', 'url.query', 'db.statement')
$sensitiveRecordKeys = @('authorization', 'user.id', 'session.id', 'url.full', 'db.statement', 'exception.message')

function New-Attr([string]$Key, [string]$Value) {
  return @{ key = $Key; value = @{ stringValue = $Value } }
}

function New-SensitiveAttrs([string[]]$Keys) {
  return @($Keys | ForEach-Object { New-Attr $_ $sentinel })
}

function Invoke-Otlp([string]$Path, [hashtable]$Body) {
  $json = $Body | ConvertTo-Json -Depth 40 -Compress
  Invoke-RestMethod `
    -Method Post `
    -Uri "$($script:LocalOtlpUrl)/$Path" `
    -Headers @{ Authorization = "Bearer $($script:LocalBearerToken)" } `
    -ContentType 'application/json' `
    -Body $json | Out-Null
}

function Assert-Sanitized([string]$Signal, [string]$Payload, [string[]]$Keys) {
  if ([string]::IsNullOrWhiteSpace($Payload)) {
    throw "$Signal canary: backend returned no data for marker $marker (signal not delivered or not queryable)."
  }
  if ($Payload -notmatch [regex]::Escape($marker)) {
    throw "$Signal canary: benign marker $marker missing after boundary (delivery/query failure)."
  }
  if ($Payload -match [regex]::Escape($sentinel)) {
    throw "$Signal canary: sensitive sentinel value crossed the boundary."
  }
  foreach ($key in $Keys) {
    if ($Payload -match [regex]::Escape($key)) {
      throw "$Signal canary: sensitive attribute key '$key' crossed the boundary."
    }
  }
  Write-Host "$Signal canary passed: marker present, all sensitive attributes removed."
}

Push-Location $root
try {
  $nowMs = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $nowNs = ($nowMs * 1000000).ToString()
  $endNs = ($nowMs + 300000) * 1000000
  $startNs = ($nowMs - 300000) * 1000000

  $traceId = -join (1..32 | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })
  $spanId = -join (1..16 | ForEach-Object { '{0:x}' -f (Get-Random -Maximum 16) })

  $traceBody = @{
    resourceSpans = @(@{
        resource   = @{ attributes = @(
            (New-Attr 'service.name' 'canary-traces'),
            (New-Attr 'canary.marker' $marker)
          ) + (New-SensitiveAttrs $sensitiveResourceKeys) }
        scopeSpans = @(@{
            scope = @{ name = 'signal-canary' }
            spans = @(@{
                traceId           = $traceId
                spanId            = $spanId
                name              = 'canary-span'
                kind              = 1
                startTimeUnixNano = $nowNs
                endTimeUnixNano   = $nowNs
                attributes        = @((New-Attr 'canary.marker' $marker)) + (New-SensitiveAttrs $sensitiveRecordKeys)
              })
          })
      })
  }
  Invoke-Otlp 'v1/traces' $traceBody

  $logBody = @{
    resourceLogs = @(@{
        resource  = @{ attributes = @(
            (New-Attr 'service.name' 'canary-logs'),
            (New-Attr 'canary.marker' $marker)
          ) + (New-SensitiveAttrs $sensitiveResourceKeys) }
        scopeLogs = @(@{
            scope      = @{ name = 'signal-canary' }
            logRecords = @(@{
                timeUnixNano   = $nowNs
                severityNumber = 9
                severityText   = 'INFO'
                body           = @{ stringValue = "canary log $marker" }
                attributes     = @((New-Attr 'canary.marker' $marker)) + (New-SensitiveAttrs $sensitiveRecordKeys)
              })
          })
      })
  }
  Invoke-Otlp 'v1/logs' $logBody

  $lokiQuery = '%7Bservice_name%3D%22canary-logs%22%7D'
  $lokiUrl = "http://loki:3100/loki/api/v1/query_range?query=$lokiQuery&start=$startNs&end=$endNs&limit=200"
  $tempoUrl = "http://tempo:3200/api/traces/$traceId"

  $tracePayload = ''
  $logPayload = ''
  for ($attempt = 1; $attempt -le 12; $attempt++) {
    Start-Sleep -Seconds 3
    if ([string]::IsNullOrWhiteSpace($tracePayload) -or $tracePayload -notmatch [regex]::Escape($marker)) {
      $tracePayload = Invoke-InClusterHttp $tempoUrl
    }
    if ([string]::IsNullOrWhiteSpace($logPayload) -or $logPayload -notmatch [regex]::Escape($marker)) {
      $logPayload = Invoke-InClusterHttp $lokiUrl
    }
    $haveTrace = $tracePayload -match [regex]::Escape($marker)
    $haveLog = $logPayload -match [regex]::Escape($marker)
    if ($haveTrace -and $haveLog) { break }
  }

  Assert-Sanitized 'Trace' $tracePayload $sensitiveRecordKeys
  Assert-Sanitized 'Log' $logPayload $sensitiveRecordKeys

  Write-Host 'Signal sanitation canary passed: traces and logs delivered with zero sensitive attributes after the boundary.'
}
finally {
  Pop-Location
}
