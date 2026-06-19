#Requires -Version 7
param(
    [Parameter(Mandatory)][string]$Hash,
    [Parameter(Mandatory)][string]$Message
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$branch = git branch --show-current
if ($branch -eq 'main') {
    Write-Error "Already on main. Switch to the feature branch first."
    exit 1
}

Write-Host "==> Squashing commits since '$Hash' into one commit..."
git reset --soft $Hash
git commit -m $Message
Write-Host ""
Write-Host "==> Current log:"
git log --oneline -6
