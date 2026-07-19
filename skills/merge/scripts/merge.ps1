#Requires -Version 7
param([string]$BaseBranch)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Merge.Common.psm1') -Force

$base = Get-MergeBaseBranch -RequestedBranch $BaseBranch
& (Join-Path $PSScriptRoot 'merge-1-check.ps1') -BaseBranch $base
Write-Output ''
$confirm = Read-Host 'WIP commits at the tip are already squashed (or none exist)? [y/N]'
if ($confirm -notin @('y', 'Y')) {
    throw 'Merge cancelled before rebase.'
}

& (Join-Path $PSScriptRoot 'merge-3-rebase.ps1') -BaseBranch $base
& (Join-Path $PSScriptRoot 'merge-1-check.ps1') -BaseBranch $base
$squash = Read-Host 'Squash all branch commits into one logical topic commit? [y/N]'
if ($squash -in @('y', 'Y')) {
    $message = Read-Host 'Commit message'
    if ([string]::IsNullOrWhiteSpace($message)) {
        throw 'A non-empty commit message is required.'
    }
    & (Join-Path $PSScriptRoot 'merge-2-squash.ps1') -Hash $base -Message $message -BaseBranch $base
}

& (Join-Path $PSScriptRoot 'merge-4-finish.ps1') -BaseBranch $base
