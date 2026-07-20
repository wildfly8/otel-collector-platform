[CmdletBinding()]
param(
  [ValidateSet('check', 'grafana', 'gcp-foundation', 'image', 'gcp-runtime', 'rules', 'all')]
  [string]$Phase = 'check',
  [switch]$PlanOnly,
  [switch]$Force
)

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$grafanaDir = Join-Path $root 'infra\grafana-cloud'
$gcpDir = Join-Path $root 'infra\gcp'
$grafanaTfvars = Join-Path $grafanaDir 'terraform.tfvars'
$gcpTfvars = Join-Path $gcpDir 'terraform.tfvars'
$imageTag = '0.1.0'

function Test-Placeholder([string]$Value) {
  return [string]::IsNullOrWhiteSpace($Value) -or $Value -match '^(REPLACE_|your-|replace-with|glc_\.\.\.)'
}

function Ensure-Tfvars {
  if (-not (Test-Path $grafanaTfvars)) {
    @"
# Local only - gitignored. Replace placeholders before apply.
enable_stack              = true
cloud_access_policy_token = "REPLACE_WITH_GRAFANA_CLOUD_PORTAL_TOKEN"
stack_slug                = "your-existing-stack-slug"
stack_id                  = "REPLACE_WITH_STACK_ID"
region_slug               = "prod-us-east-0"
"@ | Set-Content -LiteralPath $grafanaTfvars -Encoding utf8
    Write-Host "Created $grafanaTfvars"
  }

  if (-not (Test-Path $gcpTfvars)) {
    $ingestToken = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 48 | ForEach-Object { [char]$_ })
    @"
# Local only - gitignored. Replace placeholders before apply.
project_id        = "REPLACE_WITH_GCP_PROJECT_ID"
region            = "us-central1"
enable_foundation = false
enable_runtime    = false
service_name      = "otel-collector-platform"
collector_image   = ""

# Generated locally; rotate before production if this file was ever shared.
ingest_bearer_token         = "$ingestToken"
grafana_cloud_otlp_endpoint = "REPLACE_AFTER_GRAFANA_APPLY"
grafana_cloud_instance_id   = "REPLACE_AFTER_GRAFANA_APPLY"
grafana_cloud_token         = "REPLACE_AFTER_GRAFANA_APPLY"
"@ | Set-Content -LiteralPath $gcpTfvars -Encoding utf8
    Write-Host "Created $gcpTfvars (ingest token auto-generated)"
  }
}

function Invoke-Terraform([string]$Dir, [string[]]$ExtraArgs) {
  Push-Location $Dir
  try {
    terraform init -input=false | Out-Host
    if ($LASTEXITCODE -ne 0) { throw "terraform init failed in $Dir" }
    & terraform @ExtraArgs
    if ($LASTEXITCODE -ne 0) { throw "terraform $($ExtraArgs -join ' ') failed in $Dir" }
  }
  finally {
    Pop-Location
  }
}

function Get-Tfvar([string]$Path, [string]$Name) {
  $line = Select-String -LiteralPath $Path -Pattern "^\s*$Name\s*=" | Select-Object -First 1
  if (-not $line) { return $null }
  return ($line.Line -replace "^\s*$Name\s*=\s*", '').Trim().Trim('"')
}

function Sync-GrafanaOutputsToGcp {
  Push-Location $grafanaDir
  try {
    $endpoint = terraform output -raw otlp_gateway_hint 2>$null
    $instance = terraform output -raw otlp_instance_id 2>$null
    $token = terraform output -raw otlp_write_token 2>$null
  }
  finally {
    Pop-Location
  }
  if (-not $endpoint -or -not $instance -or -not $token) {
    Write-Warning 'Grafana outputs unavailable; run Phase grafana apply first.'
    return
  }
  $content = Get-Content -LiteralPath $gcpTfvars -Raw
  $content = $content -replace '(?m)^grafana_cloud_otlp_endpoint\s*=.*', "grafana_cloud_otlp_endpoint = `"$endpoint`""
  $content = $content -replace '(?m)^grafana_cloud_instance_id\s*=.*', "grafana_cloud_instance_id   = `"$instance`""
  $content = $content -replace '(?m)^grafana_cloud_token\s*=.*', "grafana_cloud_token         = `"$token`""
  Set-Content -LiteralPath $gcpTfvars -Value $content -Encoding utf8 -NoNewline
  Write-Host 'Synced Grafana OTLP outputs into infra/gcp/terraform.tfvars'
}

function Invoke-Check {
  Ensure-Tfvars
  $tools = @(
    @{ Name = 'terraform'; Cmd = 'terraform version' },
    @{ Name = 'docker'; Cmd = 'docker version' },
    @{ Name = 'gcloud'; Cmd = 'gcloud version' }
  )
  foreach ($tool in $tools) {
    try {
      Invoke-Expression $tool.Cmd | Out-Null
      Write-Host "[ok] $($tool.Name)"
    }
    catch {
      Write-Warning "[missing] $($tool.Name) - required for later phases"
    }
  }

  Invoke-Terraform $grafanaDir @('validate')
  Invoke-Terraform $gcpDir @('validate')

  Write-Host ''
  Write-Host 'Placeholder review (edit infra/*/terraform.tfvars before apply):'
  foreach ($pair in @(
      @{ File = $grafanaTfvars; Key = 'cloud_access_policy_token' },
      @{ File = $grafanaTfvars; Key = 'stack_id' },
      @{ File = $gcpTfvars; Key = 'project_id' },
      @{ File = $gcpTfvars; Key = 'grafana_cloud_otlp_endpoint' }
    )) {
    $val = Get-Tfvar $pair.File $pair.Key
    $status = if (Test-Placeholder $val) { 'REPLACE' } else { 'set' }
    Write-Host "  $($pair.Key): $status"
  }
}

function Invoke-Grafana {
  Ensure-Tfvars
  $token = Get-Tfvar $grafanaTfvars 'cloud_access_policy_token'
  if (Test-Placeholder $token) {
    throw 'Set cloud_access_policy_token in infra/grafana-cloud/terraform.tfvars before apply.'
  }
  $stackId = Get-Tfvar $grafanaTfvars 'stack_id'
  if (Test-Placeholder $stackId) {
    Write-Warning 'stack_id is not set — Terraform will call stacks:read API. If your token lacks stacks:read, set stack_id in infra/grafana-cloud/terraform.tfvars.'
  }
  if ($PlanOnly) {
    Invoke-Terraform $grafanaDir @('plan', '-var-file=terraform.tfvars')
  }
  else {
    Invoke-Terraform $grafanaDir @('apply', '-var-file=terraform.tfvars', '-auto-approve')
    Sync-GrafanaOutputsToGcp
  }
}

function Invoke-GcpFoundation {
  Ensure-Tfvars
  $project = Get-Tfvar $gcpTfvars 'project_id'
  if (Test-Placeholder $project) {
    throw 'Set project_id in infra/gcp/terraform.tfvars before apply.'
  }
  $content = Get-Content -LiteralPath $gcpTfvars -Raw
  if ($content -notmatch 'enable_foundation\s*=\s*true') {
    $content = $content -replace '(?m)^enable_foundation\s*=.*', 'enable_foundation = true'
    Set-Content -LiteralPath $gcpTfvars -Value $content -Encoding utf8 -NoNewline
  }
  $args = @('plan', '-var-file=terraform.tfvars')
  if (-not $PlanOnly) { $args = @('apply', '-var-file=terraform.tfvars', '-auto-approve') }
  Invoke-Terraform $gcpDir $args
}

function Invoke-Image {
  Ensure-Tfvars
  $project = Get-Tfvar $gcpTfvars 'project_id'
  $region = Get-Tfvar $gcpTfvars 'region'
  if (Test-Placeholder $project) {
    throw 'Set project_id in infra/gcp/terraform.tfvars before building image.'
  }
  $image = "$region-docker.pkg.dev/$project/otel-collector/collector:$imageTag"
  Push-Location $root
  try {
    & gcloud auth configure-docker "$region-docker.pkg.dev" --quiet
    docker build --platform linux/amd64 -t $image .
    if ($PlanOnly) {
      Write-Host "[plan-only] Would push $image"
      return
    }
    docker push $image
    if ($LASTEXITCODE -ne 0) {
      throw "docker push failed for $image (exit $LASTEXITCODE). Run 'gcloud auth login' then retry Phase image."
    }
    $content = Get-Content -LiteralPath $gcpTfvars -Raw
    $content = $content -replace '(?m)^collector_image\s*=.*', "collector_image   = `"$image`""
    Set-Content -LiteralPath $gcpTfvars -Value $content -Encoding utf8 -NoNewline
    Write-Host "Pushed and recorded collector_image = $image"
  }
  finally {
    Pop-Location
  }
}

function Invoke-GcpRuntime {
  Ensure-Tfvars
  Sync-GrafanaOutputsToGcp
  $project = Get-Tfvar $gcpTfvars 'project_id'
  $image = Get-Tfvar $gcpTfvars 'collector_image'
  $ingest = Get-Tfvar $gcpTfvars 'ingest_bearer_token'
  foreach ($check in @(
      @{ Name = 'project_id'; Value = $project },
      @{ Name = 'collector_image'; Value = $image },
      @{ Name = 'ingest_bearer_token'; Value = $ingest },
      @{ Name = 'grafana_cloud_otlp_endpoint'; Value = (Get-Tfvar $gcpTfvars 'grafana_cloud_otlp_endpoint') }
    )) {
    if (Test-Placeholder $check.Value) {
      throw ('Set {0} in infra/gcp/terraform.tfvars (complete grafana and image phases first).' -f $check.Name)
    }
  }
  $content = Get-Content -LiteralPath $gcpTfvars -Raw
  if ($content -notmatch 'enable_runtime\s*=\s*true') {
    $content = $content -replace '(?m)^enable_runtime\s*=.*', 'enable_runtime = true'
    Set-Content -LiteralPath $gcpTfvars -Value $content -Encoding utf8 -NoNewline
  }
  $args = @('plan', '-var-file=terraform.tfvars')
  if (-not $PlanOnly) { $args = @('apply', '-var-file=terraform.tfvars', '-auto-approve') }
  Invoke-Terraform $gcpDir $args

  if (-not $PlanOnly) {
    Push-Location $gcpDir
    try {
      Write-Host ''
      Write-Host 'Producer hint (store ingest token securely):'
      terraform output producer_environment_hint
      terraform output cloud_run_uri
    }
    finally {
      Pop-Location
    }
  }
}

function Invoke-Rules {
  if ($PlanOnly) {
    & (Join-Path $PSScriptRoot 'push-platform-rules.ps1') -DryRun
    return
  }
  Push-Location $grafanaDir
  try {
    $env:GRAFANA_CLOUD_PROM_URL = terraform output -raw prometheus_url
    $env:GRAFANA_CLOUD_PROM_USER = terraform output -raw prometheus_user_id
    $env:GRAFANA_CLOUD_RULES_TOKEN = terraform output -raw producer_rules_token
  }
  finally {
    Pop-Location
  }
  & (Join-Path $PSScriptRoot 'push-platform-rules.ps1')
}

Ensure-Tfvars

switch ($Phase) {
  'check' { Invoke-Check }
  'grafana' { Invoke-Grafana }
  'gcp-foundation' { Invoke-GcpFoundation }
  'image' { Invoke-Image }
  'gcp-runtime' { Invoke-GcpRuntime }
  'rules' { Invoke-Rules }
  'all' {
    Invoke-Check
    if (-not $PlanOnly) {
      Invoke-Grafana
      Invoke-GcpFoundation
      Invoke-Image
      Invoke-GcpRuntime
      Invoke-Rules
    }
    else {
      Write-Host 'Plan-only: run individual phases after filling terraform.tfvars placeholders.'
      Invoke-Grafana
      Invoke-GcpFoundation
      Invoke-Image
      Invoke-GcpRuntime
      Invoke-Rules
    }
  }
}
