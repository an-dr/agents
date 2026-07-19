#Requires -Version 7
param([string]$BaseBranch)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Merge.Common.psm1') -Force

$base = Get-MergeBaseBranch -RequestedBranch $BaseBranch
$branch = Assert-MergeFeatureBranch -BaseBranch $base
Assert-GitCleanWorkingTree

Write-Output "Refreshing 'origin/$base'..."
Invoke-GitCommand -Arguments @('fetch', 'origin', $base)
Assert-GitAncestor -Ancestor "origin/$base" -Descendant 'HEAD'
Write-Output "Fast-forwarding '$base' to '$branch'..."
Invoke-GitCommand -Arguments @('checkout', $base)
Invoke-GitCommand -Arguments @('merge', '--ff-only', $branch)
Write-Output "Pushing '$base'..."
Invoke-GitCommand -Arguments @('push', 'origin', $base)
Assert-GitAncestor -Ancestor $branch -Descendant $base
Write-Output "Deleting local feature branch '$branch'..."
Invoke-GitCommand -Arguments @('branch', '-D', $branch)
if (Test-GitRemoteBranch -Branch $branch) {
    Write-Output "Deleting remote feature branch '$branch'..."
    Invoke-GitCommand -Arguments @('push', 'origin', '--delete', $branch)
}
else {
    Write-Output "Remote feature branch '$branch' does not exist; skipping deletion."
}
Write-Output ''
Invoke-GitCommand -Arguments @('log', '--oneline', '-5')
Write-Output "Merge complete. Feature branch '$branch' was removed."
