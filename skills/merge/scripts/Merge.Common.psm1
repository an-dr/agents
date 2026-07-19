Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-GitCommand {
    <# Runs Git and throws with captured output on any nonzero exit. #>
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Arguments)

    $output = @(& git @Arguments)
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        throw "git $($Arguments -join ' ') failed with exit code $exitCode. See Git output above."
    }
    return $output
}

function Test-GitLocalBranch {
    <# Reports whether a local branch exists. #>
    param([Parameter(Mandatory)][string]$Branch)

    & git show-ref --verify --quiet "refs/heads/$Branch"
    return $LASTEXITCODE -eq 0
}

function Get-GitCurrentBranch {
    <# Returns the checked-out branch and rejects detached HEAD. #>
    $branch = (@(Invoke-GitCommand -Arguments @('branch', '--show-current')) -join '').Trim()
    if ([string]::IsNullOrWhiteSpace($branch)) {
        throw 'Merge operations require a checked-out branch, not detached HEAD.'
    }
    return $branch
}

function Get-MergeBaseBranch {
    <# Resolves an explicit base or detects the repository default branch. #>
    param([string]$RequestedBranch)

    if ($RequestedBranch) {
        if (-not (Test-GitLocalBranch -Branch $RequestedBranch)) {
            throw "Local base branch '$RequestedBranch' does not exist."
        }
        return $RequestedBranch
    }

    $remoteHead = @(& git symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>$null)
    if ($LASTEXITCODE -eq 0 -and $remoteHead.Count -gt 0) {
        $candidate = ([string]$remoteHead[0]) -replace '^origin/', ''
        if (Test-GitLocalBranch -Branch $candidate) {
            return $candidate
        }
    }
    foreach ($candidate in @('main', 'master', 'trunk')) {
        if (Test-GitLocalBranch -Branch $candidate) {
            return $candidate
        }
    }
    throw 'Cannot detect the base branch. Pass -BaseBranch explicitly.'
}

function Assert-MergeFeatureBranch {
    <# Verifies that HEAD is a feature branch and returns its name. #>
    param([Parameter(Mandatory)][string]$BaseBranch)

    $branch = Get-GitCurrentBranch
    if ($branch -eq $BaseBranch) {
        throw "Already on base branch '$BaseBranch'. Switch to the feature branch first."
    }
    return $branch
}

function Assert-GitCleanWorkingTree {
    <# Rejects tracked, staged, and untracked working-tree changes. #>
    $status = @(Invoke-GitCommand -Arguments @('status', '--porcelain'))
    if ($status.Count -gt 0) {
        throw 'Working tree is not clean. Commit or stash changes first.'
    }
}

function Assert-GitAncestor {
    <# Verifies that one commit is an ancestor of another. #>
    param(
        [Parameter(Mandatory)][string]$Ancestor,
        [Parameter(Mandatory)][string]$Descendant
    )

    & git merge-base --is-ancestor $Ancestor $Descendant
    if ($LASTEXITCODE -ne 0) {
        throw "'$Ancestor' is not an ancestor of '$Descendant'."
    }
}

function Test-GitRemoteBranch {
    <# Reports remote-branch existence and distinguishes transport failures. #>
    param([Parameter(Mandatory)][string]$Branch)

    $output = @(& git ls-remote --exit-code --heads origin "refs/heads/$Branch" 2>&1)
    if ($LASTEXITCODE -eq 0) { return $true }
    if ($LASTEXITCODE -eq 2) { return $false }
    $detail = ($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine
    throw "Unable to inspect origin branch '$Branch'.$([Environment]::NewLine)$detail"
}

Export-ModuleMember -Function Assert-GitAncestor, Assert-GitCleanWorkingTree,
    Assert-MergeFeatureBranch, Get-GitCurrentBranch, Get-MergeBaseBranch,
    Invoke-GitCommand, Test-GitLocalBranch, Test-GitRemoteBranch
