#Requires -Version 7
param([string]$BaseBranch)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Merge.Common.psm1') -Force

$base = Get-MergeBaseBranch -RequestedBranch $BaseBranch
Assert-MergeFeatureBranch -BaseBranch $base | Out-Null
Assert-GitCleanWorkingTree

Write-Output "Fetching 'origin/$base'..."
Invoke-GitCommand -Arguments @('fetch', 'origin', $base)
Write-Output "Rebasing onto 'origin/$base'..."
Invoke-GitCommand -Arguments @('rebase', "origin/$base")
Write-Output ''
Invoke-GitCommand -Arguments @('log', '--oneline', "$base..HEAD")
