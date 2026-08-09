Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../../git-integrate/scripts/Integrate.Common.psm1') -Force

function Resolve-RewriteRange {
    <# Resolves the linear commit range to rewrite and rejects unsafe states. #>
    param(
        [string]$Range,
        [switch]$FromRoot,
        [switch]$AllowDirty
    )

    $branch = Get-GitCurrentBranch
    if (-not $AllowDirty) { Assert-GitCleanWorkingTree }

    if ($FromRoot) {
        $roots = @(Invoke-GitCommand -Arguments @('rev-list', '--max-parents=0', 'HEAD'))
        if ($roots.Count -ne 1) {
            throw "Branch '$branch' has $($roots.Count) root commits; pass -Range instead."
        }
        $base = $null
        $commits = @(Invoke-GitCommand -Arguments @('rev-list', '--reverse', 'HEAD'))
        $mergeSpec = @('rev-list', '--min-parents=2', 'HEAD')
    }
    else {
        if ($Range) {
            $base = (@(Invoke-GitCommand -Arguments @('rev-parse', "$Range^{commit}")) -join '').Trim()
        }
        else {
            $default = Get-IntegrateBaseBranch
            if ($branch -eq $default) {
                throw "On default branch '$default'. Pass -Range <rev> or -FromRoot deliberately."
            }
            $base = (@(Invoke-GitCommand -Arguments @('merge-base', $default, 'HEAD')) -join '').Trim()
        }
        Assert-GitAncestor -Ancestor $base -Descendant 'HEAD'
        $commits = @(Invoke-GitCommand -Arguments @('rev-list', '--reverse', "$base..HEAD"))
        $mergeSpec = @('rev-list', '--min-parents=2', "$base..HEAD")
    }

    if ($commits.Count -eq 0) { throw 'The selected range holds no commits.' }
    $merges = @(Invoke-GitCommand -Arguments $mergeSpec)
    if ($merges.Count -gt 0) {
        throw 'Message rewriting requires linear history; the range contains merge commits.'
    }

    return [pscustomobject]@{
        Branch     = $branch
        BaseCommit = $base
        Commits    = $commits
    }
}

function Get-CommitMessageText {
    <# Returns one commit's full message. #>
    param([Parameter(Mandatory)][string]$Commit)

    return (@(Invoke-GitCommand -Arguments @('show', '-s', '--format=%B', $Commit)) -join "`n")
}

Export-ModuleMember -Function Get-CommitMessageText, Resolve-RewriteRange
