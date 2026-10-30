#Requires -Version 7
<#
Lands a RebaseMerge pull request with the platform's rebase and merge, so
the base gains the branch's commits and no merge commit.

-TestedCommit names the commit whose CI passed. The local branch may differ
from it only in history (fixups folded, commits regrouped), never in tree:
the script refuses otherwise. When the local branch is not yet on the
remote, it force-pushes it and cancels the CI runs that push starts, because
that tree has already passed.
#>
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$TestedCommit,
    [string]$BaseBranch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Integrate.Common.psm1') -Force

if (-not (Test-IntegrateGhCli)) {
    throw 'RebaseMerge needs the GitHub CLI (gh) to merge the request.'
}
$base = Get-IntegrateBaseBranch -RequestedBranch $BaseBranch
$branch = Assert-IntegrateFeatureBranch -BaseBranch $base
Assert-GitCleanWorkingTree

function Get-Tree([string]$Commit) {
    return (@(Invoke-GitCommand -Arguments @('rev-parse', "$Commit^{tree}")) -join '').Trim()
}

$tested = (@(Invoke-GitCommand -Arguments @('rev-parse', $TestedCommit)) -join '').Trim()
$head = (@(Invoke-GitCommand -Arguments @('rev-parse', 'HEAD')) -join '').Trim()
if ((Get-Tree $tested) -ne (Get-Tree $head)) {
    throw "HEAD's tree differs from $TestedCommit's, so its CI result does not cover HEAD. Push it and let CI run."
}

$runs = @(& gh run list --commit $tested --json conclusion,name | ConvertFrom-Json)
if ($LASTEXITCODE -ne 0 -or $runs.Count -eq 0) {
    throw "No CI runs found for $TestedCommit."
}
$unpassed = @($runs | Where-Object { $_.conclusion -notin @('success', 'skipped') })
if ($unpassed.Count -gt 0) {
    throw "CI has not passed for ${TestedCommit}: $(($unpassed | ForEach-Object { "$($_.name)=$($_.conclusion)" }) -join ', ')"
}

Invoke-GitCommand -Arguments @('fetch', 'origin', $branch) | Out-Null
$remote = (@(Invoke-GitCommand -Arguments @('rev-parse', "origin/$branch")) -join '').Trim()
if ($remote -ne $head) {
    Write-Output "Pushing '$branch'; its tree passed CI as $TestedCommit."
    Invoke-GitCommand -Arguments @('push', '--force-with-lease', 'origin', $branch)
    # Runs register a few seconds after the push, so look for a while.
    $cancelled = @{}
    for ($try = 0; $try -lt 6; $try++) {
        Start-Sleep -Seconds 5
        $started = @(& gh run list --commit $head --json databaseId,status | ConvertFrom-Json)
        foreach ($run in $started | Where-Object { $_.status -ne 'completed' -and -not $cancelled[$_.databaseId] }) {
            & gh run cancel $run.databaseId | Out-Null
            $cancelled[$run.databaseId] = $true
            Write-Output "Cancelled CI run $($run.databaseId)."
        }
    }
}

Write-Output "Rebase-merging '$branch' into '$base'..."
& gh pr merge $branch --rebase --delete-branch
if ($LASTEXITCODE -ne 0) {
    throw 'gh pr merge failed. See the output above; nothing was merged.'
}
if ((Get-GitCurrentBranch) -ne $base) {
    Invoke-GitCommand -Arguments @('checkout', $base)
}
Invoke-GitCommand -Arguments @('pull', '--ff-only', 'origin', $base)
if (Test-GitLocalBranch -Branch $branch) {
    Invoke-GitCommand -Arguments @('branch', '-D', $branch)
}
Write-Output ''
Invoke-GitCommand -Arguments @('log', '--oneline', '-5')
Write-Output "Integration complete. '$branch' was rebase-merged and removed."
