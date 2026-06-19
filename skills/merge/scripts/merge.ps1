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

Write-Host "==> Checking for WIP commits..."
git log --oneline -6

Write-Host ""
Write-Host "If WIP commits exist at the tip that touch the same concern, squash them now:"
Write-Host "  git reset --soft <hash-before-wips>; git commit -m '<clean message>'"
Write-Host "Then re-run this script."
$confirm = Read-Host "WIPs squashed (or none exist)? [y/N]"
if ($confirm -notin @('y', 'Y')) { Write-Host "Aborted."; exit 1 }

Write-Host "==> Fetching and rebasing on origin/main..."
git fetch origin
git rebase origin/main

Write-Host "==> Reviewing commits to squash..."
git log --oneline main..HEAD
Write-Host ""
$squash = Read-Host "Run interactive rebase to squash related-topic commits? [y/N]"
if ($squash -in @('y', 'Y')) {
    git rebase -i main
}

Write-Host "==> Fast-forwarding main..."
git checkout main
git merge --ff-only $branch

Write-Host "==> Pushing main..."
git push origin main

Write-Host "==> Deleting feature branch..."
git branch -d $branch
try { git push origin --delete $branch } catch { Write-Host "(remote branch not found, skipping)" }

Write-Host ""
git log --oneline -5
Write-Host ""
Write-Host "Merge complete. Branch '$branch' deleted."
