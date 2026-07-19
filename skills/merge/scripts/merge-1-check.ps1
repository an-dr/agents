#Requires -Version 7
param([string]$BaseBranch)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Merge.Common.psm1') -Force

$base = Get-MergeBaseBranch -RequestedBranch $BaseBranch
$branch = Assert-MergeFeatureBranch -BaseBranch $base
Assert-GitCleanWorkingTree

Write-Output "Feature branch: $branch"
Write-Output "Base branch: $base"
Write-Output ''
Write-Output 'Recent commits (check for WIPs at the tip):'
Invoke-GitCommand -Arguments @('log', '--oneline', '-6')
Write-Output ''
Write-Output "Commits on '$branch' since '$base':"
Invoke-GitCommand -Arguments @('log', '--oneline', "$base..HEAD")
Write-Output ''
Write-Output 'Preconditions OK.'
