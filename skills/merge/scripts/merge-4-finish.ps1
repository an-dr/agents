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
    Write-Error "Working tree is not clean."
    exit 1
}

Write-Host "==> Fast-forwarding main..."
git checkout main
git merge --ff-only $branch

Write-Host "==> Pushing main..."
git push origin main

Write-Host "==> Deleting feature branch '$branch'..."
git branch -d $branch
try { git push origin --delete $branch } catch { Write-Host "(remote branch not found, skipping)" }

Write-Host ""
git log --oneline -5
Write-Host ""
Write-Host "Merge complete. Branch '$branch' deleted."
