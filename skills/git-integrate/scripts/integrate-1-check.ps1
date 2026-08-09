#Requires -Version 7
param([string]$BaseBranch)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Integrate.Common.psm1') -Force

$base = Get-IntegrateBaseBranch -RequestedBranch $BaseBranch
$branch = Assert-IntegrateFeatureBranch -BaseBranch $base
Assert-GitCleanWorkingTree

$progressPaths = @(Invoke-GitCommand -Arguments @(
        'log', '--format=', '--name-only', "$base..HEAD", '--', '.progress'
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
if ($progressPaths.Count -gt 0) {
    throw 'Feature-branch history contains .progress. Run the dev-workflow-clean-branch skill before integration.'
}

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
