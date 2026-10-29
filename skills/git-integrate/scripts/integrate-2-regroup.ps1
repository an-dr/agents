#Requires -Version 7
<#
Rebuilds the feature branch as the logical commits a plan names, for the
Regroup mode. The plan is a JSON file:

    { "commits": [ { "message": "<git-commit message>", "paths": ["dir", "file"] } ] }

Commits are made in plan order from the branch's final tree; each stages its
paths with `git add -A`. Every message is checked before anything is touched,
the branch is kept under a backup ref, and any failure restores it. The
result must hold exactly the original tree.
#>
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Plan,
    [string]$BaseBranch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Integrate.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../../git-commit/scripts/GitCommit.Format.psm1') -Force

$base = Get-IntegrateBaseBranch -RequestedBranch $BaseBranch
$branch = Assert-IntegrateFeatureBranch -BaseBranch $base
Assert-GitCleanWorkingTree

$commits = @((Get-Content -Raw -LiteralPath $Plan | ConvertFrom-Json).commits)
if ($commits.Count -eq 0) {
    throw "The plan '$Plan' lists no commits."
}

# A message rejected halfway would leave its group staged for the next
# commit, so every message passes before the history is touched.
$scopes = Get-DeclaredScope
$rejected = 0
for ($i = 0; $i -lt $commits.Count; $i++) {
    $entry = $commits[$i]
    if (-not $entry.message -or @($entry.paths).Count -eq 0) {
        throw "Plan commit $($i + 1) needs a message and at least one path."
    }
    $violations = @(Get-CommitMessageViolation -Message $entry.message -AllowedScope $scopes)
    Write-CommitViolation -Violation $violations -Label "Plan commit $($i + 1) message check:"
    $rejected += Measure-CommitError -Violation $violations
}
if ($rejected -gt 0) {
    throw 'A plan message breaks the git-commit format; nothing was regrouped.'
}

$point = Get-IntegrateSquashPoint -BaseBranch $base
$tree = (@(Invoke-GitCommand -Arguments @('rev-parse', 'HEAD^{tree}')) -join '').Trim()
$backup = "backup/$branch-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Invoke-GitCommand -Arguments @('branch', $backup, 'HEAD') | Out-Null
Write-Output "Kept the branch as '$backup'."

try {
    Invoke-GitCommand -Arguments @('reset', '--mixed', '--quiet', $point) | Out-Null
    for ($i = 0; $i -lt $commits.Count; $i++) {
        $entry = $commits[$i]
        Invoke-GitCommand -Arguments (@('add', '-A', '--') + @($entry.paths)) | Out-Null
        & git diff --cached --quiet
        if ($LASTEXITCODE -eq 0) {
            throw "Plan commit $($i + 1) stages nothing; its paths hold no change, or an earlier commit took them."
        }
        Invoke-GitCommand -Arguments @('commit', '--quiet', '-m', $entry.message) | Out-Null
    }
    $left = @(Invoke-GitCommand -Arguments @('status', '--porcelain'))
    if ($left.Count -gt 0) {
        throw "No plan commit covers:$([Environment]::NewLine)$($left -join [Environment]::NewLine)"
    }
    $result = (@(Invoke-GitCommand -Arguments @('rev-parse', 'HEAD^{tree}')) -join '').Trim()
    if ($result -ne $tree) {
        throw 'The regrouped tree differs from the original.'
    }
}
catch {
    # Restored exactly, so the backup holds nothing the branch does not.
    & git reset --hard --quiet $backup
    & git branch -D --quiet $backup
    throw "Regrouping failed and the branch was restored as it was: $($_.Exception.Message)"
}

Write-Output "Rebuilt '$branch' as $($commits.Count) commits with its tree unchanged:"
Invoke-GitCommand -Arguments @('log', '--oneline', "$point..HEAD")
