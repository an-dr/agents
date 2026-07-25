#Requires -Version 7
[CmdletBinding()]
param([string]$BaseBranch)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$integrateModule = Join-Path $PSScriptRoot '../../integrate/scripts/Integrate.Common.psm1'
Import-Module $integrateModule -Force

function Set-ProcessEnvironmentValue {
    param(
        [Parameter(Mandatory)][string]$Name,
        [AllowNull()][string]$Value
    )

    if ([string]::IsNullOrEmpty($Value)) {
        Remove-Item -LiteralPath "Env:$Name" -ErrorAction SilentlyContinue
    }
    else {
        Set-Item -LiteralPath "Env:$Name" -Value $Value
    }
}

$base = Get-IntegrateBaseBranch -RequestedBranch $BaseBranch
$branch = Assert-IntegrateFeatureBranch -BaseBranch $base
Assert-GitCleanWorkingTree

$mergeBase = (@(Invoke-GitCommand -Arguments @('merge-base', $base, 'HEAD')) -join '').Trim()
Assert-GitAncestor -Ancestor $mergeBase -Descendant 'HEAD'

$mergeCommits = @(Invoke-GitCommand -Arguments @(
        'rev-list', '--min-parents=2', "$mergeBase..HEAD"
    ))
if ($mergeCommits.Count -gt 0) {
    throw 'remove-progress requires linear feature-branch history; integrate merge commits before continuing.'
}

$progressPaths = @(Invoke-GitCommand -Arguments @(
        'log', '--format=', '--name-only', "$mergeBase..HEAD", '--', '.progress'
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
if ($progressPaths.Count -eq 0) {
    Write-Output "No .progress history exists on '$branch'; nothing to rewrite."
    return
}

$commits = @(Invoke-GitCommand -Arguments @('rev-list', '--reverse', "$mergeBase..HEAD"))
$oldTip = (@(Invoke-GitCommand -Arguments @('rev-parse', 'HEAD')) -join '').Trim()
$newParent = $mergeBase
$previousOldParent = $mergeBase
$rewritten = 0
$pruned = 0
$temporaryIndex = Join-Path ([IO.Path]::GetTempPath()) (
    'agents-remove-progress-{0}.index' -f [guid]::NewGuid()
)
$messagePath = [IO.Path]::GetTempFileName()
$savedIndex = [Environment]::GetEnvironmentVariable('GIT_INDEX_FILE')
$metadataKeys = @(
    'GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_AUTHOR_DATE',
    'GIT_COMMITTER_NAME', 'GIT_COMMITTER_EMAIL', 'GIT_COMMITTER_DATE'
)
$savedMetadata = @{}
foreach ($key in $metadataKeys) {
    $savedMetadata[$key] = [Environment]::GetEnvironmentVariable($key)
}

try {
    Set-ProcessEnvironmentValue -Name GIT_INDEX_FILE -Value $temporaryIndex
    foreach ($commit in $commits) {
        $parentText = (@(Invoke-GitCommand -Arguments @(
                    'show', '-s', '--format=%P', $commit
                )) -join '').Trim()
        $parents = @($parentText -split '\s+' | Where-Object { $_ })
        if ($parents.Count -ne 1 -or $parents[0] -ne $previousOldParent) {
            throw "Commit '$commit' is not part of the expected linear feature-branch chain."
        }

        Invoke-GitCommand -Arguments @('read-tree', $commit) | Out-Null
        Invoke-GitCommand -Arguments @(
            'rm', '-r', '--cached', '--ignore-unmatch', '--', '.progress'
        ) | Out-Null
        $tree = (@(Invoke-GitCommand -Arguments @('write-tree')) -join '').Trim()
        $parentTree = (@(Invoke-GitCommand -Arguments @(
                    'rev-parse', "$newParent^{tree}"
                )) -join '').Trim()

        if ($tree -eq $parentTree) {
            $pruned++
            $previousOldParent = $commit
            continue
        }

        $message = (@(Invoke-GitCommand -Arguments @(
                    'show', '-s', '--format=%B', $commit
                )) -join "`n")
        [IO.File]::WriteAllText($messagePath, "$message`n", [Text.UTF8Encoding]::new($false))

        $metadata = @{
            GIT_AUTHOR_NAME     = (@(Invoke-GitCommand -Arguments @('show', '-s', '--format=%an', $commit)) -join '')
            GIT_AUTHOR_EMAIL    = (@(Invoke-GitCommand -Arguments @('show', '-s', '--format=%ae', $commit)) -join '')
            GIT_AUTHOR_DATE     = (@(Invoke-GitCommand -Arguments @('show', '-s', '--format=%aI', $commit)) -join '')
            GIT_COMMITTER_NAME  = (@(Invoke-GitCommand -Arguments @('show', '-s', '--format=%cn', $commit)) -join '')
            GIT_COMMITTER_EMAIL = (@(Invoke-GitCommand -Arguments @('show', '-s', '--format=%ce', $commit)) -join '')
            GIT_COMMITTER_DATE  = (@(Invoke-GitCommand -Arguments @('show', '-s', '--format=%cI', $commit)) -join '')
        }
        foreach ($entry in $metadata.GetEnumerator()) {
            Set-ProcessEnvironmentValue -Name $entry.Key -Value ([string]$entry.Value)
        }
        try {
            $newParent = (@(Invoke-GitCommand -Arguments @(
                        'commit-tree', $tree, '-p', $newParent, '-F', $messagePath
                    )) -join '').Trim()
        }
        finally {
            foreach ($key in $metadata.Keys) {
                Set-ProcessEnvironmentValue -Name $key -Value $savedMetadata[$key]
            }
        }

        $rewritten++
        $previousOldParent = $commit
    }

    Invoke-GitCommand -Arguments @(
        'update-ref', "refs/heads/$branch", $newParent, $oldTip
    ) | Out-Null
}
finally {
    Set-ProcessEnvironmentValue -Name GIT_INDEX_FILE -Value $savedIndex
    foreach ($key in $metadataKeys) {
        Set-ProcessEnvironmentValue -Name $key -Value $savedMetadata[$key]
    }
    Remove-Item -Force -LiteralPath $temporaryIndex -ErrorAction SilentlyContinue
    Remove-Item -Force -LiteralPath $messagePath -ErrorAction SilentlyContinue
}

# `update-ref` moves HEAD without refreshing the real index. The precondition
# guarantees there were no staged changes to preserve.
Invoke-GitCommand -Arguments @('reset', '--mixed', 'HEAD') | Out-Null

$remainingTreePaths = @(Invoke-GitCommand -Arguments @(
        'ls-tree', '-r', '--name-only', 'HEAD', '--', '.progress'
    ))
$remainingHistoryPaths = @(Invoke-GitCommand -Arguments @(
        'log', '--format=', '--name-only', "$mergeBase..HEAD", '--', '.progress'
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
if ($remainingTreePaths.Count -gt 0 -or $remainingHistoryPaths.Count -gt 0) {
    throw '.progress still exists after history rewriting.'
}
Assert-GitCleanWorkingTree

Write-Output "Removed .progress from '$branch' history: $rewritten commit(s) rewritten, $pruned progress-only commit(s) pruned."
Write-Output "New branch tip: $newParent"
