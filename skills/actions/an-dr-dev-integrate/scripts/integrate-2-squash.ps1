#Requires -Version 7
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Hash,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$CommitMessageSkill,
    [string]$BaseBranch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Integrate.Common.psm1') -Force
# Messages are checked through commit-message's public CLI, never its modules. The agent
# passes that skill's folder, because skills need not be installed side by side.
$checkMessage = Join-Path $CommitMessageSkill 'scripts/check-message.ps1'
if (-not (Test-Path -LiteralPath $checkMessage)) {
    throw "-CommitMessageSkill must be the commit-message folder; '$checkMessage' is missing."
}

$base = Get-IntegrateBaseBranch -RequestedBranch $BaseBranch
Assert-IntegrateFeatureBranch -BaseBranch $base | Out-Null
Assert-GitCleanWorkingTree
Invoke-GitCommand -Arguments @('rev-parse', '--verify', "$Hash^{commit}") | Out-Null
Assert-GitAncestor -Ancestor $Hash -Descendant 'HEAD'

# The squashed commit is delivered history, so it obeys the commit message format.
& $checkMessage -Message $Message -Label 'Squash message check:' -Quiet
if ($LASTEXITCODE -ne 0) {
    throw 'The squash message breaks the commit message format; nothing was squashed.'
}

Write-Output "Squashing commits after '$Hash' into one commit..."
Invoke-GitCommand -Arguments @('reset', '--soft', $Hash) | Out-Null
Invoke-GitCommand -Arguments @('commit', '-m', $Message)
Write-Output ''
Invoke-GitCommand -Arguments @('log', '--oneline', '-6')
