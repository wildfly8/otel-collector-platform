function Invoke-Until(
  [scriptblock]$Action,
  [scriptblock]$Success,
  [int]$Attempts = 12,
  [int]$DelaySeconds = 5,
  [string]$Label = 'operation'
) {
  for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
    $result = & $Action
    if (& $Success $result) { return $result }
    if ($attempt -lt $Attempts) {
      Start-Sleep -Seconds $DelaySeconds
    }
  }
  throw "$Label did not succeed after $Attempts attempts."
}

function New-GrafanaBasicAuth([string]$User, [string]$Token) {
  $pair = "$User`:$Token"
  return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pair))
}

function Invoke-GrafanaGet([string]$Url, [string]$User, [string]$Token) {
  $auth = New-GrafanaBasicAuth $User $Token
  return Invoke-WebRequest `
    -Method Get `
    -Uri $Url `
    -Headers @{ Authorization = "Basic $auth" } `
    -UseBasicParsing
}
