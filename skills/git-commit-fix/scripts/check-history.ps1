#Requires -Version 7
<#
    Reports every commit in a range whose message breaks the git-commit format.
    Changes nothing; exits non-zero when any commit needs rewriting.
#>
[CmdletBinding()]
param(
    [string]$Range,
    [switch]$FromRoot,
    [switch]$FailingOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'GitCommitFix.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../../git-commit/scripts/GitCommit.Format.psm1') -Force

$target = Resolve-RewriteRange -Range $Range -FromRoot:$FromRoot -AllowDirty
$declaredScopes = Get-DeclaredScope
$failing = 0

foreach ($commit in $target.Commits) {
    $short = (@(& git rev-parse --short $commit) -join '').Trim()
    $message = Get-CommitMessageText -Commit $commit
    $subject = ($message -split "`n")[0]
    $violations = @(Get-CommitMessageViolation -Message $message -AllowedScope $declaredScopes)
    $errorCount = Measure-CommitError -Violation $violations

    if ($errorCount -gt 0) { $failing++ }
    if ($FailingOnly -and $errorCount -eq 0) { continue }

    if ($violations.Count -eq 0) { Write-Output "$short $subject" }
    else { Write-CommitViolation -Violation $violations -Label "$short $subject" }
}

Write-Output ''
Write-Output "$($target.Commits.Count) commit(s) checked, $failing need rewriting."
if ($failing -gt 0) {
    Write-Output "Write replacements to a directory as <sha>.txt, then run rewrite-messages.ps1."
    exit 1
}
