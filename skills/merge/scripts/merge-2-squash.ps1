#Requires -Version 7
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Hash,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message,
    [string]$BaseBranch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Merge.Common.psm1') -Force

$base = Get-MergeBaseBranch -RequestedBranch $BaseBranch
Assert-MergeFeatureBranch -BaseBranch $base | Out-Null
Assert-GitCleanWorkingTree
Invoke-GitCommand -Arguments @('rev-parse', '--verify', "$Hash^{commit}") | Out-Null
Assert-GitAncestor -Ancestor $Hash -Descendant 'HEAD'

Write-Output "Squashing commits after '$Hash' into one commit..."
Invoke-GitCommand -Arguments @('reset', '--soft', $Hash) | Out-Null
Invoke-GitCommand -Arguments @('commit', '-m', $Message)
Write-Output ''
Invoke-GitCommand -Arguments @('log', '--oneline', '-6')
