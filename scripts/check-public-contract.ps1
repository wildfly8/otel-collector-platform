[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$contract = Join-Path $root 'contracts/public/otel-ingest'
$versionFile = Join-Path $contract 'VERSION'

$requiredFiles = @(
  'README.md',
  'VERSION',
  'CHANGELOG.md',
  'contract.yaml',
  'api-contract.md',
  'data-contract.md',
  'capability.md'
)

foreach ($file in $requiredFiles) {
  $path = Join-Path $contract $file
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Public contract is missing required file: $file"
  }
}

$version = (Get-Content -LiteralPath $versionFile -Raw).Trim()
if ($version -notmatch '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$') {
  throw "Public contract VERSION is not stable semantic versioning: '$version'"
}

$expectedReferences = @{
  'contracts/public/otel-ingest/README.md' = @(
    "Version**: ``$version``",
    "contracts/otel-ingest/v$version"
  )
  'contracts/public/otel-ingest/CHANGELOG.md' = @("## $version")
  'contracts/public/otel-ingest/contract.yaml' = @(
    "version: $version",
    "releaseTag: contracts/otel-ingest/v$version",
    'api: api-contract.md',
    'data: data-contract.md',
    'capability: capability.md'
  )
  'specs/dependencies.yaml' = @(
    "version: $version",
    'path: contracts/public/otel-ingest'
  )
  'specs/001-central-otel-collector/contracts/producer-ingest.md' = @(
    "``$version``",
    "contracts/otel-ingest/v$version"
  )
}

foreach ($relativePath in $expectedReferences.Keys) {
  $path = Join-Path $root $relativePath
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "Contract reference file is missing: $relativePath"
  }
  $content = Get-Content -LiteralPath $path -Raw
  foreach ($reference in $expectedReferences[$relativePath]) {
    if (-not $content.Contains($reference)) {
      throw "$relativePath does not reference contract version '$version' consistently (missing '$reference')."
    }
  }
}

$requiredSections = @{
  'api-contract.md' = @('## Protocol and endpoints', '## Authentication', '## Delivery and failure behavior')
  'data-contract.md' = @('## Resource identity', '## Metric admission', '## Sanitation and normalization', '## Compatibility')
  'capability.md' = @('## Platform guarantees', '## Producer responsibilities', '## Non-capabilities')
}

foreach ($file in $requiredSections.Keys) {
  $content = Get-Content -LiteralPath (Join-Path $contract $file) -Raw
  foreach ($section in $requiredSections[$file]) {
    if (-not $content.Contains($section)) {
      throw "$file is missing required section '$section'."
    }
  }
}

Write-Host "Public contract otel-ingest@$version is structurally valid."
