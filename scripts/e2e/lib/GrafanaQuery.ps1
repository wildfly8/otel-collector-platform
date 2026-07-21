# Grafana Cloud query helpers for cloud E2E (HTTP API or direct LGTM Basic auth).

function Get-GrafanaDataSourceUid(
  [string]$StackUrl,
  [string]$ApiToken,
  [string]$Kind
) {
  $base = $StackUrl.TrimEnd('/')
  $slug = ($base -replace '^https://', '').Split('.')[0]
  $expectedName = switch ($Kind) {
    'prometheus' { "grafanacloud-$slug-prom" }
    'loki' { "grafanacloud-$slug-logs" }
    'tempo' { "grafanacloud-$slug-traces" }
    default { throw "Unknown datasource kind '$Kind'." }
  }
  $items = (Invoke-WebRequest `
      -Uri "$base/api/datasources" `
      -Headers @{ Authorization = "Bearer $ApiToken" } `
      -UseBasicParsing).Content | ConvertFrom-Json
  $match = @($items | Where-Object { $_.name -eq $expectedName })[0]
  if (-not $match) {
    $match = @($items | Where-Object {
        $_.type -eq $Kind -and $_.name -notmatch 'usage|insights|alert'
      } | Sort-Object { $_.name -like "grafanacloud-$slug-*" } -Descending)[0]
  }
  if (-not $match) { throw "No Grafana '$Kind' datasource found on $base." }
  return $match.uid
}

function Invoke-GrafanaDsQuery(
  [string]$StackUrl,
  [string]$ApiToken,
  [hashtable]$Query,
  [string]$FromMs,
  [string]$ToMs
) {
  $base = $StackUrl.TrimEnd('/')
  $body = @{
    queries = @($Query)
    from    = $FromMs
    to      = $ToMs
  } | ConvertTo-Json -Depth 12 -Compress
  return Invoke-WebRequest `
    -Method Post `
    -Uri "$base/api/ds/query" `
    -Headers @{
      Authorization  = "Bearer $ApiToken"
      'Content-Type' = 'application/json'
    } `
    -Body $body `
    -UseBasicParsing
}

function Test-GrafanaPromMetric(
  [string]$StackUrl,
  [string]$ApiToken,
  [string]$Expr,
  [string]$MustMatch
) {
  $uid = Get-GrafanaDataSourceUid $StackUrl $ApiToken 'prometheus'
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $from = ($now - 900000).ToString()
  $to = $now.ToString()
  $r = Invoke-GrafanaDsQuery $StackUrl $ApiToken @{
    refId      = 'A'
    expr       = $Expr
    instant    = $true
    range      = $false
    datasource = @{ type = 'prometheus'; uid = $uid }
  } $from $to
  return $r.StatusCode -eq 200 -and $r.Content -match [regex]::Escape($MustMatch)
}

function Test-GrafanaLokiMarker(
  [string]$StackUrl,
  [string]$ApiToken,
  [string]$Expr,
  [string]$Marker
) {
  $uid = Get-GrafanaDataSourceUid $StackUrl $ApiToken 'loki'
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $from = ($now - 900000).ToString()
  $to = ($now + 120000).ToString()
  $r = Invoke-GrafanaDsQuery $StackUrl $ApiToken @{
    refId      = 'A'
    expr       = $Expr
    queryType  = 'range'
    datasource = @{ type = 'loki'; uid = $uid }
  } $from $to
  return $r.StatusCode -eq 200 -and $r.Content -match [regex]::Escape($Marker)
}

function Test-GrafanaTempoTrace(
  [string]$StackUrl,
  [string]$ApiToken,
  [string]$TraceId,
  [string]$Marker
) {
  $uid = Get-GrafanaDataSourceUid $StackUrl $ApiToken 'tempo'
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $from = ($now - 900000).ToString()
  $to = ($now + 120000).ToString()
  $queries = @(
  @{ query = $TraceId; label = 'trace-id' },
  @{ query = "{ resource.e2e.marker = `"$Marker`" }"; label = 'marker' },
  @{ query = "{ resource.service.name = `"e2e-traces`" }"; label = 'service' }
  )
  foreach ($q in $queries) {
    try {
      $r = Invoke-GrafanaDsQuery $StackUrl $ApiToken @{
        refId      = 'A'
        query      = $q.query
        queryType  = 'traceql'
        limit      = 5
        datasource = @{ type = 'tempo'; uid = $uid }
      } $from $to
      if ($r.StatusCode -eq 200 -and $r.Content -match [regex]::Escape($Marker)) {
        return $true
      }
      if ($r.StatusCode -eq 200 -and $r.Content -match [regex]::Escape($TraceId)) {
        return $true
      }
    }
    catch {
      continue
    }
  }
  return $false
}

function Test-UsesGrafanaHttpApi([string]$QueryToken) {
  return [string]::IsNullOrWhiteSpace($QueryToken) -or $QueryToken.Length -lt 80
}
