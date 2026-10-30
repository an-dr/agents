#Requires -Version 7
<#
    Interactive integration. Always asks which mode to use. Regroup needs a
    plan, so it is run through the step scripts instead.
#>
param(
    # The agent passes the convention's folder, because skills need not be installed side by side.
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$CommitMessageSkill,
    [string]$BaseBranch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Integrate.Common.psm1') -Force

$base = Get-IntegrateBaseBranch -RequestedBranch $BaseBranch
& (Join-Path $PSScriptRoot 'remove-progress.ps1') -BaseBranch $base
& (Join-Path $PSScriptRoot 'integrate-1-check.ps1') -BaseBranch $base
Write-Output ''
$confirm = Read-Host 'WIP commits at the tip are already squashed (or none exist)? [y/N]'
if ($confirm -notin @('y', 'Y')) {
    throw 'Integration cancelled before rebase.'
}

& (Join-Path $PSScriptRoot 'integrate-3-rebase.ps1') -BaseBranch $base
& (Join-Path $PSScriptRoot 'integrate-1-check.ps1') -BaseBranch $base

Write-Output ''
Write-Output 'Integration mode:'
Write-Output "  1  Commits  keep every commit, fast-forward '$base' (no merge commit)"
Write-Output "  2  Squash   collapse the branch into one commit, fast-forward '$base'"
Write-Output '  3  Request  collapse into one commit, push the branch, open a request'
Write-Output '  4  RebaseMerge  push the branch with its commits, open a request;'
Write-Output '                 integrate-5-rebase-merge.ps1 lands it once CI passes'
$mode = ''
while (-not $mode) {
    switch ((Read-Host 'Choose 1, 2, 3, or 4').Trim()) {
        '1' { $mode = 'Commits' }
        '2' { $mode = 'Squash' }
        '3' { $mode = 'Request' }
        '4' { $mode = 'RebaseMerge' }
        default { Write-Output 'Answer 1, 2, 3, or 4.' }
    }
}

$message = ''
if ($mode -in @('Squash', 'Request')) {
    Write-Output 'The commit message must match the commit message format; the squash is rejected otherwise.'
    $message = Read-Host 'Single commit subject'
    if ([string]::IsNullOrWhiteSpace($message)) {
        throw 'A non-empty commit message is required.'
    }
}

& (Join-Path $PSScriptRoot 'integrate-4-finish.ps1') -Mode $mode -Message $message -BaseBranch $base -CommitMessageSkill $CommitMessageSkill
