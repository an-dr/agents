#Requires -Version 7
param(
    [string]$BaseBranch,
    # an-dr-ai-use-wip-data's folder: the base the work started from is read through it.
    [Parameter(Mandatory)][string]$WipDataSkill
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Integrate.Common.psm1') -Force

$base = Get-IntegrateBaseBranch -RequestedBranch $BaseBranch -WipDataSkill $WipDataSkill
$branch = Assert-IntegrateFeatureBranch -BaseBranch $base
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
$tmp = @(Get-IntegrateTmpPath -BaseBranch $base)
if ($tmp.Count -gt 0) {
    Write-Output "Tmp files on the branch, stripped from every commit by step 3: $($tmp -join ', ')"
    Write-Output ''
}
Write-Output 'Preconditions OK.'
