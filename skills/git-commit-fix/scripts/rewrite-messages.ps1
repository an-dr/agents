#Requires -Version 7
<#
    Replaces commit messages across a linear range, changing nothing else.
    Trees, authors, committers, and dates are preserved; a backup ref is kept.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$MessageDirectory,
    [string]$Range,
    [switch]$FromRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'GitCommitFix.Common.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../../git-commit/scripts/GitCommit.Format.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../../git-integrate/scripts/Integrate.Common.psm1') -Force

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

if (-not (Test-Path -LiteralPath $MessageDirectory)) {
    throw "Message directory '$MessageDirectory' does not exist."
}
$target = Resolve-RewriteRange -Range $Range -FromRoot:$FromRoot
$rangeCommits = [System.Collections.Generic.HashSet[string]]::new()
foreach ($commit in $target.Commits) { [void]$rangeCommits.Add($commit) }

# Resolve every <sha>.txt to a full hash and reject anything outside the range.
$replacements = @{}
foreach ($file in Get-ChildItem -LiteralPath $MessageDirectory -Filter '*.txt') {
    $key = [IO.Path]::GetFileNameWithoutExtension($file.Name)
    $resolved = (@(& git rev-parse --verify --quiet "$key^{commit}") -join '').Trim()
    if ($LASTEXITCODE -ne 0 -or -not $resolved) {
        throw "File '$($file.Name)' does not name a commit."
    }
    if (-not $rangeCommits.Contains($resolved)) {
        throw "Commit '$key' lies outside the selected range."
    }
    $replacements[$resolved] = [IO.File]::ReadAllText($file.FullName)
}
if ($replacements.Count -eq 0) { throw "No <sha>.txt messages found in '$MessageDirectory'." }

# Validate every replacement before touching history.
$declaredScopes = Get-DeclaredScope
$errorCount = 0
foreach ($entry in $replacements.GetEnumerator()) {
    $short = (@(Invoke-GitCommand -Arguments @('rev-parse', '--short', $entry.Key)) -join '').Trim()
    $violations = @(Get-CommitMessageViolation -Message $entry.Value -AllowedScope $declaredScopes)
    Write-CommitViolation -Violation $violations -Label "$short replacement:"
    $errorCount += Measure-CommitError -Violation $violations
}
if ($errorCount -gt 0) {
    Write-Output "$errorCount rule violation(s) in the replacements; history was not touched."
    exit 1
}

$oldTip = (@(Invoke-GitCommand -Arguments @('rev-parse', 'HEAD')) -join '').Trim()
$backupRef = "refs/backup/git-commit-fix/$($target.Branch)/$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Invoke-GitCommand -Arguments @('update-ref', $backupRef, $oldTip) | Out-Null

$messagePath = [IO.Path]::GetTempFileName()
$metadataKeys = @(
    'GIT_AUTHOR_NAME', 'GIT_AUTHOR_EMAIL', 'GIT_AUTHOR_DATE',
    'GIT_COMMITTER_NAME', 'GIT_COMMITTER_EMAIL', 'GIT_COMMITTER_DATE'
)
$savedMetadata = @{}
foreach ($key in $metadataKeys) {
    $savedMetadata[$key] = [Environment]::GetEnvironmentVariable($key)
}
$newParent = $target.BaseCommit
$rewritten = 0

try {
    foreach ($commit in $target.Commits) {
        $tree = (@(Invoke-GitCommand -Arguments @('rev-parse', "$commit^{tree}")) -join '').Trim()
        if ($replacements.ContainsKey($commit)) {
            $message = $replacements[$commit]
            $rewritten++
        }
        else {
            $message = Get-CommitMessageText -Commit $commit
        }
        if (-not $message.EndsWith("`n")) { $message += "`n" }
        [IO.File]::WriteAllText($messagePath, $message, [Text.UTF8Encoding]::new($false))

        $metadata = @{
            GIT_AUTHOR_NAME     = (@(Invoke-GitCommand -Arguments @('show', '-s', '--format=%an', $commit)) -join '')
            GIT_AUTHOR_EMAIL    = (@(Invoke-GitCommand -Arguments @('show', '-s', '--format=%ae', $commit)) -join '')
            GIT_AUTHOR_DATE     = (@(Invoke-GitCommand -Arguments @('show', '-s', '--format=%aI', $commit)) -join '')
            GIT_COMMITTER_NAME  = (@(Invoke-GitCommand -Arguments @('show', '-s', '--format=%cn', $commit)) -join '')
            GIT_COMMITTER_EMAIL = (@(Invoke-GitCommand -Arguments @('show', '-s', '--format=%ce', $commit)) -join '')
            GIT_COMMITTER_DATE  = (@(Invoke-GitCommand -Arguments @('show', '-s', '--format=%cI', $commit)) -join '')
        }
        foreach ($item in $metadata.GetEnumerator()) {
            Set-ProcessEnvironmentValue -Name $item.Key -Value ([string]$item.Value)
        }
        try {
            $arguments = @('commit-tree', $tree)
            if ($newParent) { $arguments += @('-p', $newParent) }
            $arguments += @('-F', $messagePath)
            $newParent = (@(Invoke-GitCommand -Arguments $arguments) -join '').Trim()
        }
        finally {
            foreach ($key in $metadata.Keys) {
                Set-ProcessEnvironmentValue -Name $key -Value $savedMetadata[$key]
            }
        }
    }

    Invoke-GitCommand -Arguments @(
        'update-ref', "refs/heads/$($target.Branch)", $newParent, $oldTip
    ) | Out-Null
}
finally {
    foreach ($key in $metadataKeys) {
        Set-ProcessEnvironmentValue -Name $key -Value $savedMetadata[$key]
    }
    Remove-Item -Force -LiteralPath $messagePath -ErrorAction SilentlyContinue
}

Invoke-GitCommand -Arguments @('reset', '--mixed', 'HEAD') | Out-Null

# Only messages may have changed, so the new tip must match the old one exactly.
& git diff --quiet $oldTip HEAD
if ($LASTEXITCODE -ne 0) {
    throw "Content changed during the rewrite. Restore with: git reset --hard $oldTip"
}
Assert-GitCleanWorkingTree

Write-Output "Rewrote $rewritten message(s) on '$($target.Branch)'; content is unchanged."
Write-Output "New tip: $newParent"
Write-Output "Backup ref: $backupRef (restore with git reset --hard $backupRef)"
