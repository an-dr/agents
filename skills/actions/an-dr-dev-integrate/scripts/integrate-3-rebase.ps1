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
Assert-IntegrateFeatureBranch -BaseBranch $base | Out-Null
Assert-GitCleanWorkingTree
Remove-IntegrateTmpHistory -BaseBranch $base

Write-Output "Fetching 'origin/$base'..."
Invoke-GitCommand -Arguments @('fetch', 'origin', $base)
Write-Output "Rebasing onto 'origin/$base'..."
Invoke-GitCommand -Arguments @('rebase', "origin/$base")
Write-Output ''
Invoke-GitCommand -Arguments @('log', '--oneline', "$base..HEAD")
