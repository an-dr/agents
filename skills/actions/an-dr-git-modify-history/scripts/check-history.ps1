#Requires -Version 7
<#
    Reports every commit in a range whose message breaks the commit message format.
    Changes nothing; exits non-zero when any commit needs rewriting.
#>
[CmdletBinding()]
param(
    [string]$Range,
    [switch]$FromRoot,
    [switch]$FailingOnly,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$CommitMessageSkill
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'GitCommitFix.Common.psm1') -Force
# Messages are checked through commit-message's public CLI, never its modules. The agent
# passes that skill's folder, because skills need not be installed side by side.
$checkMessage = Join-Path $CommitMessageSkill 'scripts/check-message.ps1'
if (-not (Test-Path -LiteralPath $checkMessage)) {
    throw "-CommitMessageSkill must be the commit-message folder; '$checkMessage' is missing."
}

$target = Resolve-RewriteRange -Range $Range -FromRoot:$FromRoot -AllowDirty
$failing = 0

foreach ($commit in $target.Commits) {
    $short = (@(& git rev-parse --short $commit) -join '').Trim()
    $message = Get-CommitMessageText -Commit $commit
    $subject = ($message -split "`n")[0]
    $report = @(& $checkMessage -Message $message -Label "$short $subject" -Quiet)
    $broken = $LASTEXITCODE -ne 0

    if ($broken) { $failing++ }
    if ($FailingOnly -and -not $broken) { continue }

    if ($report.Count -eq 0) { Write-Output "$short $subject" }
    else { $report }
}

Write-Output ''
Write-Output "$($target.Commits.Count) commit(s) checked, $failing need rewriting."
if ($failing -gt 0) {
    Write-Output "Write replacements to a directory as <sha>.txt, then run rewrite-messages.ps1."
    exit 1
}
