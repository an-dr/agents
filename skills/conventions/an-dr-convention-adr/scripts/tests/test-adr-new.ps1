#Requires -Version 7
<# Checks that adr-new.ps1 creates ADRs under docs/adr with contiguous numbers and the section skeleton. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Join-Path ([IO.Path]::GetTempPath()) "adr-new-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $root | Out-Null
$script = Join-Path $PSScriptRoot '../adr-new.ps1'
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
try {
    Push-Location -LiteralPath $root
    try {
        git init --quiet
        & $script -Title 'Use a shared folder' | Out-Null
        & $script -Title 'Keep one wire contract' | Out-Null
    }
    finally { Pop-Location }

    $first = Join-Path $root 'docs/adr/ADR-001-use-a-shared-folder.md'
    $second = Join-Path $root 'docs/adr/ADR-002-keep-one-wire-contract.md'
    Assert (Test-Path -LiteralPath $first) "Expected $first."
    Assert (Test-Path -LiteralPath $second) "Expected $second."
    $created = @(Get-ChildItem -LiteralPath (Join-Path $root 'docs') -Recurse -File)
    Assert ($created.Count -eq 2) "Expected exactly two files under docs/, got: $($created.FullName -join ', ')"
    $text = Get-Content -LiteralPath $first -Raw
    foreach ($heading in '# ADR-001: Use a shared folder', '## Problem', '## Decision', '## Rationale', '## Rejected alternatives') {
        Assert ($text.Contains($heading)) "Missing '$heading' in $first."
    }
    Write-Output 'ADR creation checks passed.'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force
}
