#Requires -Version 7
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Hash,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message,
    [string]$BaseBranch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Integrate.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../../git-commit/scripts/GitCommit.Format.psm1') -Force

$base = Get-IntegrateBaseBranch -RequestedBranch $BaseBranch
Assert-IntegrateFeatureBranch -BaseBranch $base | Out-Null
Assert-GitCleanWorkingTree
Invoke-GitCommand -Arguments @('rev-parse', '--verify', "$Hash^{commit}") | Out-Null
Assert-GitAncestor -Ancestor $Hash -Descendant 'HEAD'

# The squashed commit is delivered history, so it obeys the git-commit format.
$violations = @(Get-CommitMessageViolation -Message $Message -AllowedScope (Get-DeclaredScope))
Write-CommitViolation -Violation $violations -Label 'Squash message check:'
if ((Measure-CommitError -Violation $violations) -gt 0) {
    throw 'The squash message breaks the git-commit format; nothing was squashed.'
}

Write-Output "Squashing commits after '$Hash' into one commit..."
Invoke-GitCommand -Arguments @('reset', '--soft', $Hash) | Out-Null
Invoke-GitCommand -Arguments @('commit', '-m', $Message)
Write-Output ''
Invoke-GitCommand -Arguments @('log', '--oneline', '-6')
