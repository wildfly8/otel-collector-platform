function Get-TfvarValue([string]$Path, [string]$Name) {
  if (-not (Test-Path $Path)) { return $null }
  $line = Select-String -LiteralPath $Path -Pattern "^\s*$Name\s*=" | Select-Object -First 1
  if (-not $line) { return $null }
  return ($line.Line -replace "^\s*$Name\s*=\s*", '').Trim().Trim('"')
}

function Get-TerraformOutput([string]$Dir, [string]$Name) {
  if (-not (Test-Path $Dir)) { return $null }
  Push-Location $Dir
  try {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $raw = terraform output -raw $Name 2>$null
    $ErrorActionPreference = $prev
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($raw)) { return $null }
    return $raw.Trim()
  }
  finally {
    Pop-Location
  }
}

function Get-GrafanaStackField([string]$Dir, [string]$Field) {
  if (-not (Test-Path $Dir)) { return $null }
  Push-Location $Dir
  try {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    $show = (& terraform state show 'data.grafana_cloud_stack.platform[0]' 2>&1 | Out-String)
    $ErrorActionPreference = $prev
    if ([string]::IsNullOrWhiteSpace($show)) { return $null }
    $pattern = "(?m)^\s*$([regex]::Escape($Field))\s+=\s+`"([^`"]+)`""
    $match = [regex]::Match($show, $pattern)
    if ($match.Success) {
      return $match.Groups[1].Value
    }
    return $null
  }
  finally {
    Pop-Location
  }
}

function Resolve-CloudE2EConfig {
  $root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..')
  $gcpTfvars = Join-Path $root 'infra\gcp\terraform.tfvars'
  $gcpDir = Join-Path $root 'infra\gcp'
  $grafanaDir = Join-Path $root 'infra\grafana-cloud'

  $config = [ordered]@{
    CloudRunUri            = $env:CLOUD_RUN_URI
    IngestBearerToken      = $env:INGEST_BEARER_TOKEN
    GrafanaStackUrl        = $env:GRAFANA_STACK_URL
    GrafanaApiToken        = $env:GRAFANA_CLOUD_API_TOKEN
    GrafanaPromUrl         = $env:GRAFANA_CLOUD_PROM_URL
    GrafanaPromUser        = $env:GRAFANA_CLOUD_PROM_USER
    GrafanaLogsUrl         = $env:GRAFANA_CLOUD_LOGS_URL
    GrafanaTempoUrl        = $env:GRAFANA_CLOUD_TEMPO_URL
    GrafanaQueryToken      = $env:GRAFANA_CLOUD_QUERY_TOKEN
  }

  if ([string]::IsNullOrWhiteSpace($config.CloudRunUri)) {
    $config.CloudRunUri = Get-TerraformOutput $gcpDir 'cloud_run_uri'
  }
  if ([string]::IsNullOrWhiteSpace($config.IngestBearerToken)) {
    $config.IngestBearerToken = Get-TfvarValue $gcpTfvars 'ingest_bearer_token'
  }
  if ([string]::IsNullOrWhiteSpace($config.GrafanaStackUrl)) {
    $config.GrafanaStackUrl = Get-TerraformOutput $grafanaDir 'stack_url'
  }
  if ([string]::IsNullOrWhiteSpace($config.GrafanaApiToken)) {
    $config.GrafanaApiToken = Get-TerraformOutput $grafanaDir 'producer_provisioner_token'
  }
  if ([string]::IsNullOrWhiteSpace($config.GrafanaPromUrl)) {
    $config.GrafanaPromUrl = Get-TerraformOutput $grafanaDir 'prometheus_url'
  }
  if ([string]::IsNullOrWhiteSpace($config.GrafanaPromUser)) {
    $config.GrafanaPromUser = Get-TerraformOutput $grafanaDir 'prometheus_user_id'
    if ([string]::IsNullOrWhiteSpace($config.GrafanaPromUser)) {
      $config.GrafanaPromUser = Get-TerraformOutput $grafanaDir 'otlp_instance_id'
    }
  }
  if ([string]::IsNullOrWhiteSpace($config.GrafanaLogsUrl)) {
    $config.GrafanaLogsUrl = Get-TerraformOutput $grafanaDir 'logs_url'
    if ([string]::IsNullOrWhiteSpace($config.GrafanaLogsUrl)) {
      $config.GrafanaLogsUrl = Get-GrafanaStackField $grafanaDir 'logs_url'
    }
  }
  if ([string]::IsNullOrWhiteSpace($config.GrafanaTempoUrl)) {
    $config.GrafanaTempoUrl = Get-TerraformOutput $grafanaDir 'traces_url'
    if ([string]::IsNullOrWhiteSpace($config.GrafanaTempoUrl)) {
      $config.GrafanaTempoUrl = Get-GrafanaStackField $grafanaDir 'traces_url'
    }
  }
  if ([string]::IsNullOrWhiteSpace($config.GrafanaQueryToken)) {
    $config.GrafanaQueryToken = Get-TerraformOutput $grafanaDir 'e2e_query_token'
  }

  return [pscustomobject]$config
}

function Test-CloudE2EConfig([pscustomobject]$Config, [switch]$RequireGrafanaQuery) {
  $missing = @()
  foreach ($name in @('CloudRunUri', 'IngestBearerToken')) {
    if ([string]::IsNullOrWhiteSpace($Config.$name)) { $missing += $name }
  }
  if ($RequireGrafanaQuery) {
    $needsHttpApi = [string]::IsNullOrWhiteSpace($Config.GrafanaQueryToken)
    if ($needsHttpApi) {
      foreach ($name in @('GrafanaStackUrl', 'GrafanaApiToken', 'GrafanaPromUser')) {
        if ([string]::IsNullOrWhiteSpace($Config.$name)) { $missing += $name }
      }
    }
    else {
      foreach ($name in @(
          'GrafanaPromUrl', 'GrafanaPromUser', 'GrafanaLogsUrl',
          'GrafanaTempoUrl', 'GrafanaQueryToken'
        )) {
        if ([string]::IsNullOrWhiteSpace($Config.$name)) { $missing += $name }
      }
    }
  }
  if ($missing.Count -gt 0) {
    $hint = ''
    if ($missing -contains 'GrafanaQueryToken' -or $missing -contains 'GrafanaApiToken') {
      $hint = ' Re-apply infra/grafana-cloud to create e2e_query_token, set GRAFANA_CLOUD_QUERY_TOKEN, or rely on GRAFANA_STACK_URL + GRAFANA_CLOUD_API_TOKEN (producer_provisioner_token).'
    }
    throw ("Missing cloud E2E configuration: {0}. Set env vars or apply infra and keep local tfvars/terraform state.{1}" -f ($missing -join ', '), $hint)
  }
}
