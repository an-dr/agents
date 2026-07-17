#Requires -Version 7
param(
    [Parameter(Mandatory)][string]$Title
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = git rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0) { exit 1 }
$dir = Join-Path $root 'docs/adr'
New-Item -ItemType Directory -Force $dir | Out-Null

$max = 0
Get-ChildItem $dir -Filter 'ADR-*.md' | ForEach-Object {
    if ($_.Name -match '^ADR-(\d+)') { $max = [Math]::Max($max, [int]$Matches[1]) }
}
$num = '{0:d3}' -f ($max + 1)

$slug = ($Title.ToLower() -replace '[^a-z0-9]+', '-').Trim('-')
$path = Join-Path $dir "ADR-$num-$slug.md"

@"
# ADR-${num}: $Title

## Problem

## Decision

## Rationale

## Rejected alternatives
"@ | Set-Content $path

Write-Host "Created $path"
