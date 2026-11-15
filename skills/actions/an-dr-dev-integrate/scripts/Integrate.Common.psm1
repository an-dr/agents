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
        throw 'Integration operations require a checked-out branch, not detached HEAD.'
    }
    return $branch
}

function Get-WorkflowStateBaseBranch {
    <# workflow.baseBranch from tmp-agent-wip.json, read through an-dr-ai-use-wip-data; empty when absent. #>
    param([Parameter(Mandatory)][string]$WipDataSkill)

    $wip = Join-Path $WipDataSkill 'scripts/wip.ps1'
    if (-not (Test-Path -LiteralPath $wip)) { throw "-WipDataSkill must be an-dr-ai-use-wip-data's folder; '$wip' does not exist." }
    $json = (@(& $wip get -Section workflow -Field baseBranch -Reader an-dr-dev-integrate) -join '')
    if (-not $json -or $json -eq 'null') { return '' }
    return [string]($json | ConvertFrom-Json)
}

function Get-IntegrateBaseBranch {
    <# Resolves an explicit base, the base the work started from, or the repository default branch. #>
    param([string]$RequestedBranch, [Parameter(Mandatory)][string]$WipDataSkill)

    if ($RequestedBranch) {
        if (-not (Test-GitLocalBranch -Branch $RequestedBranch)) {
            throw "Local base branch '$RequestedBranch' does not exist."
        }
        return $RequestedBranch
    }

    # The branch the work started from: recorded in the branch's config once
    # its tmp files are stripped, and in tmp-agent-wip.json until then.
    $current = (@(& git branch --show-current 2>$null) -join '').Trim()
    if ($current) {
        $recorded = (@(& git config --get "branch.$current.an-dr-base" 2>$null) -join '').Trim()
        if ($recorded -and (Test-GitLocalBranch -Branch $recorded)) {
            return $recorded
        }
        $fromState = Get-WorkflowStateBaseBranch -WipDataSkill $WipDataSkill
        if ($fromState -and (Test-GitLocalBranch -Branch $fromState)) {
            return $fromState
        }
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

function Assert-IntegrateFeatureBranch {
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

function Get-IntegrateSquashPoint {
    <# Returns the commit the branch's own work starts from. #>
    param([Parameter(Mandatory)][string]$BaseBranch)

    $point = (@(Invoke-GitCommand -Arguments @('merge-base', "origin/$BaseBranch", 'HEAD')) -join '').Trim()
    if ([string]::IsNullOrWhiteSpace($point)) {
        throw "Cannot locate the merge base of 'origin/$BaseBranch' and HEAD."
    }
    return $point
}

function Get-IntegrateRemoteWebUrl {
    <# Converts the origin URL to a browsable https URL, or returns an empty string. #>
    $url = (@(& git remote get-url origin 2>$null) -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or -not $url) { return '' }
    $url = $url -replace '\.git$', ''
    if ($url -match '^[^@/]+@(?<host>[^:]+):(?<path>.+)$') {
        return "https://$($Matches['host'])/$($Matches['path'])"
    }
    if ($url -match '^ssh://[^@/]+@(?<rest>.+)$') {
        return "https://$($Matches['rest'])"
    }
    return $url
}

function Test-IntegrateGhCli {
    <# Reports whether the GitHub CLI is available for opening a request. #>
    return [bool](Get-Command gh -ErrorAction SilentlyContinue)
}


# Work files every flow keeps beside the code: tmp-agent-wip.json, the
# progress page, generated reports. Any file or folder whose name starts with
# tmp- or .tmp-, at any depth. They travel on a work branch and never land.
$script:TmpPathspec = @(':(glob)**/tmp-*', ':(glob)**/tmp-*/**', ':(glob)**/.tmp-*', ':(glob)**/.tmp-*/**')

function Get-IntegrateTmpPath {
    <# The tmp paths that any commit after the base, or HEAD, still carries. #>
    param([Parameter(Mandatory)][string]$BaseBranch)

    $mergeBase = (@(Invoke-GitCommand -Arguments @('merge-base', $BaseBranch, 'HEAD')) -join '').Trim()
    $paths = @(& git log --format= --name-only "$mergeBase..HEAD" -- @script:TmpPathspec) +
        @(& git ls-tree -r --name-only HEAD -- @script:TmpPathspec)
    return @($paths | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Sort-Object -Unique)
}

function Assert-IntegrateNoTmp {
    <# Refuses to land a branch whose history still carries tmp files. #>
    param([Parameter(Mandatory)][string]$BaseBranch)

    $paths = @(Get-IntegrateTmpPath -BaseBranch $BaseBranch)
    if ($paths.Count -gt 0) {
        throw "The branch still carries tmp files ($($paths -join ', ')); run integrate-3-rebase.ps1 first."
    }
}

function Set-ProcessEnvironmentValue {
    param([Parameter(Mandatory)][string]$Name, [AllowNull()][string]$Value)
    if ([string]::IsNullOrEmpty($Value)) { Remove-Item -LiteralPath "Env:$Name" -ErrorAction SilentlyContinue }
    else { Set-Item -LiteralPath "Env:$Name" -Value $Value }
}

function Remove-IntegrateTmpHistory {
    <#
        Rewrites every commit after the base without tmp files, drops commits
        that held nothing else, and deletes the stripped files from disk.
        Records the base in the branch config first, since the state file that
        named it is one of the files removed.
    #>
    param([Parameter(Mandatory)][string]$BaseBranch)

    $branch = Get-GitCurrentBranch
    Invoke-GitCommand -Arguments @('config', "branch.$branch.an-dr-base", $BaseBranch) | Out-Null
    $stripped = @(Get-IntegrateTmpPath -BaseBranch $BaseBranch)
    if ($stripped.Count -eq 0) {
        Write-Output 'No tmp files on the branch; nothing to strip.'
        return
    }
    $mergeBase = (@(Invoke-GitCommand -Arguments @('merge-base', $BaseBranch, 'HEAD')) -join '').Trim()
    if (@(Invoke-GitCommand -Arguments @('rev-list', '--min-parents=2', "$mergeBase..HEAD")).Count -gt 0) {
        throw 'Stripping tmp files needs linear history; rebase away merge commits first.'
    }
    $commits = @(Invoke-GitCommand -Arguments @('rev-list', '--reverse', "$mergeBase..HEAD"))
    $oldTip = (@(Invoke-GitCommand -Arguments @('rev-parse', 'HEAD')) -join '').Trim()
    $newParent = $mergeBase
    $rewritten = 0
    $pruned = 0
    $index = Join-Path ([IO.Path]::GetTempPath()) ('agents-strip-tmp-{0}.index' -f [guid]::NewGuid())
    $messagePath = [IO.Path]::GetTempFileName()
    $keys = @('GIT_INDEX_FILE', 'GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_AUTHOR_DATE', 'GIT_COMMITTER_NAME', 'GIT_COMMITTER_EMAIL', 'GIT_COMMITTER_DATE')
    $saved = @{}
    foreach ($key in $keys) { $saved[$key] = [Environment]::GetEnvironmentVariable($key) }
    try {
        Set-ProcessEnvironmentValue -Name GIT_INDEX_FILE -Value $index
        foreach ($commit in $commits) {
            Invoke-GitCommand -Arguments @('read-tree', $commit) | Out-Null
            Invoke-GitCommand -Arguments (@('rm', '-r', '--cached', '--quiet', '--ignore-unmatch', '--') + $script:TmpPathspec) | Out-Null
            $tree = (@(Invoke-GitCommand -Arguments @('write-tree')) -join '').Trim()
            if ($tree -eq (@(Invoke-GitCommand -Arguments @('rev-parse', "$newParent^{tree}")) -join '').Trim()) {
                $pruned++
                continue
            }
            $message = (@(Invoke-GitCommand -Arguments @('show', '-s', '--format=%B', $commit)) -join "`n")
            [IO.File]::WriteAllText($messagePath, "$message`n", [Text.UTF8Encoding]::new($false))
            $meta = @(Invoke-GitCommand -Arguments @('show', '-s', '--format=%an%x00%ae%x00%aI%x00%cn%x00%ce%x00%cI', $commit)) -join ''
            $fields = $meta -split "`0"
            for ($i = 1; $i -lt $keys.Count; $i++) { Set-ProcessEnvironmentValue -Name $keys[$i] -Value $fields[$i - 1] }
            $newParent = (@(Invoke-GitCommand -Arguments @('commit-tree', $tree, '-p', $newParent, '-F', $messagePath)) -join '').Trim()
            $rewritten++
        }
    }
    finally {
        foreach ($key in $keys) { Set-ProcessEnvironmentValue -Name $key -Value $saved[$key] }
        Remove-Item -Force -LiteralPath $index, $messagePath -ErrorAction SilentlyContinue
    }
    Invoke-GitCommand -Arguments @('update-ref', "refs/heads/$branch", $newParent, $oldTip) | Out-Null
    # update-ref leaves the index at the old tip; the clean-tree precondition
    # means there is nothing staged to keep.
    Invoke-GitCommand -Arguments @('reset', '--quiet', '--mixed', 'HEAD') | Out-Null
    $root = (@(Invoke-GitCommand -Arguments @('rev-parse', '--show-toplevel')) -join '').Trim()
    foreach ($path in $stripped) {
        Remove-Item -LiteralPath (Join-Path $root $path) -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -LiteralPath (Join-Path $root 'tmp-agent-progress.html') -Force -ErrorAction SilentlyContinue
    Assert-IntegrateNoTmp -BaseBranch $BaseBranch
    Write-Output "Stripped $($stripped.Count) tmp path(s): $rewritten commit(s) rewritten, $pruned tmp-only commit(s) dropped."
}

Export-ModuleMember -Function Assert-GitAncestor, Assert-GitCleanWorkingTree,
    Assert-IntegrateFeatureBranch, Assert-IntegrateNoTmp, Get-GitCurrentBranch, Get-IntegrateBaseBranch,
    Get-IntegrateTmpPath, Remove-IntegrateTmpHistory,
    Get-IntegrateRemoteWebUrl, Get-IntegrateSquashPoint, Invoke-GitCommand,
    Test-GitLocalBranch, Test-GitRemoteBranch, Test-IntegrateGhCli
