#Requires -Version 7
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$branch = git branch --show-current
if ($branch -eq 'main') {
    Write-Error "Already on main. Switch to the feature branch first."
    exit 1
}

$status = git status --porcelain
if ($status) {
    Write-Error "Working tree is not clean. Commit or stash changes first."
    exit 1
}

Write-Host "Branch: $branch"
Write-Host ""
Write-Host "==> Recent commits (check for WIPs at the tip):"
git log --oneline -6
Write-Host ""
Write-Host "==> Commits on this branch since main:"
git log --oneline main..HEAD
Write-Host ""
Write-Host "Preconditions OK."
Write-Host "Next steps:"
Write-Host "  [optional] merge-2-squash.ps1 -Hash <hash-before-wips> -Message '<msg>'  # squash WIP commits"
Write-Host "             merge-3-rebase.ps1"
Write-Host "  [optional] merge-2-squash.ps1 -Hash main -Message '<msg>'                # squash topic commits"
Write-Host "             merge-4-finish.ps1"
