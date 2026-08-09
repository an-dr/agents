#Requires -Version 7
<#
    Completes the integration in the mode the user chose.
    -Mode is mandatory: the mode is a user decision and has no default.
#>
param(
    [Parameter(Mandatory)][ValidateSet('Commits', 'Squash', 'Request')][string]$Mode,
    [string]$Message,
    [string]$BaseBranch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Integrate.Common.psm1') -Force

$base = Get-IntegrateBaseBranch -RequestedBranch $BaseBranch
$branch = Assert-IntegrateFeatureBranch -BaseBranch $base
Assert-GitCleanWorkingTree
if ($Mode -ne 'Commits' -and [string]::IsNullOrWhiteSpace($Message)) {
    throw "-Mode $Mode collapses the branch into one commit, so -Message is required."
}

Write-Output "Refreshing 'origin/$base'..."
Invoke-GitCommand -Arguments @('fetch', 'origin', $base)
Assert-GitAncestor -Ancestor "origin/$base" -Descendant 'HEAD'

if ($Mode -ne 'Commits') {
    $squashPoint = Get-IntegrateSquashPoint -BaseBranch $base
    & (Join-Path $PSScriptRoot 'integrate-2-squash.ps1') `
        -Hash $squashPoint -Message $Message -BaseBranch $base
}

if ($Mode -eq 'Request') {
    if (Test-GitRemoteBranch -Branch $branch) {
        # Refresh the tracking ref so --force-with-lease compares against reality.
        Invoke-GitCommand -Arguments @('fetch', 'origin', $branch)
    }
    Write-Output "Pushing '$branch' to origin..."
    Invoke-GitCommand -Arguments @('push', '--force-with-lease', '--set-upstream', 'origin', $branch)
    if (Test-IntegrateGhCli) {
        Write-Output "Opening a pull request into '$base'..."
        & gh pr create --base $base --head $branch --fill
        if ($LASTEXITCODE -ne 0) {
            throw 'gh pr create failed. See the output above; the branch is pushed.'
        }
    }
    else {
        $web = Get-IntegrateRemoteWebUrl
        Write-Output "The GitHub CLI is not installed, so open the request by hand."
        Write-Output "  from '$branch' into '$base'$(if ($web) { " at $web" })"
    }
    Write-Output ''
    Write-Output "Request flow complete. '$base' is untouched and '$branch' still exists;"
    Write-Output 'the review platform merges it and deletes the branch.'
    return
}

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
Write-Output "Integration complete. Feature branch '$branch' was removed."
