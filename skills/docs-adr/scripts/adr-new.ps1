#Requires -Version 7
param([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Title)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($Title)) {
    throw 'ADR title cannot be blank.'
}
$root = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $root) {
    throw 'Run the ADR script inside a Git repository.'
}
$directory = Join-Path $root.Trim() 'docs/adr'
New-Item -ItemType Directory -Force -Path $directory | Out-Null
$slug = ($Title.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
if (-not $slug) {
    throw 'ADR title must contain at least one ASCII letter or number for its filename.'
}

$maximum = 0
Get-ChildItem -LiteralPath $directory -Filter 'ADR-*.md' | ForEach-Object {
    if ($_.Name -match '^ADR-(\d+)') {
        $maximum = [Math]::Max($maximum, [int]$Matches[1])
    }
}
$number = $maximum + 1
$createdPath = $null
for ($attempt = 1; $attempt -le 100; $attempt++) {
    $formattedNumber = '{0:d3}' -f $number
    $path = Join-Path $directory "ADR-$formattedNumber-$slug.md"
    try {
        $stream = [IO.File]::Open($path, 'CreateNew', 'Write', 'None')
        try {
            $content = @"
# ADR-${formattedNumber}: $Title

## Problem

## Decision

## Rationale

## Rejected alternatives
"@
            $writer = [IO.StreamWriter]::new($stream, [Text.UTF8Encoding]::new($false))
            try { $writer.Write($content) } finally { $writer.Dispose() }
            $stream = $null
        }
        finally {
            if ($stream) { $stream.Dispose() }
        }
        $createdPath = $path
        break
    }
    catch [IO.IOException] {
        if (-not (Test-Path -LiteralPath $path)) { throw }
        $number++
    }
}
if (-not $createdPath) {
    throw 'Unable to reserve an ADR number after 100 attempts.'
}

Write-Output "Created $createdPath"
