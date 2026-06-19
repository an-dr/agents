#Requires -Version 7
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$branch = git branch --show-current
if ($branch -eq 'main') {
    Write-Error "Already on main. Switch to the feature branch first."
    exit 1
}

Write-Host "==> Fetching origin..."
git fetch origin
Write-Host "==> Rebasing on origin/main..."
git rebase origin/main
Write-Host ""
Write-Host "==> Commits on this branch since main:"
git log --oneline main..HEAD
