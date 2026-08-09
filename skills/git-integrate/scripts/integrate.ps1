#Requires -Version 7
param([string]$BaseBranch)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Integrate.Common.psm1') -Force

$base = Get-IntegrateBaseBranch -RequestedBranch $BaseBranch
& (Join-Path $PSScriptRoot '../../dev-workflow-clean-branch/scripts/remove-progress.ps1') -BaseBranch $base
& (Join-Path $PSScriptRoot 'integrate-1-check.ps1') -BaseBranch $base
Write-Output ''
$confirm = Read-Host 'WIP commits at the tip are already squashed (or none exist)? [y/N]'
if ($confirm -notin @('y', 'Y')) {
    throw 'Integration cancelled before rebase.'
}

& (Join-Path $PSScriptRoot 'integrate-3-rebase.ps1') -BaseBranch $base
& (Join-Path $PSScriptRoot 'integrate-1-check.ps1') -BaseBranch $base
$squash = Read-Host 'Squash all branch commits into one logical topic commit? [y/N]'
if ($squash -in @('y', 'Y')) {
    $message = Read-Host 'Commit message'
    if ([string]::IsNullOrWhiteSpace($message)) {
        throw 'A non-empty commit message is required.'
    }
    & (Join-Path $PSScriptRoot 'integrate-2-squash.ps1') -Hash $base -Message $message -BaseBranch $base
}

& (Join-Path $PSScriptRoot 'integrate-4-finish.ps1') -BaseBranch $base
