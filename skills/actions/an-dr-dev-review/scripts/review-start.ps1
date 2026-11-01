#Requires -Version 7
<# Creates a canonical JSON review in REPO/.artifacts-temp/ai/code-review/. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Reference,
    [Parameter(Mandatory)]
    [ValidateSet('direct', 'verify', 'summary', 'requested')]
    [string]$Scope,
    # artifact-layout's folder, passed by the agent because skills need not sit side by side.
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ArtifactLayoutSkill
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Review.Common.psm1') -Force

$repositoryRoot = Get-ReviewRepositoryRoot
$reviewPath = New-ReviewPath -RepositoryRoot $repositoryRoot -ArtifactLayoutSkill $ArtifactLayoutSkill
if (Test-Path -LiteralPath $reviewPath) {
    throw "Review already exists: $reviewPath"
}
$templatePath = Join-Path $PSScriptRoot '../assets/review-template.json'
$review = Get-Content -Raw -LiteralPath $templatePath | ConvertFrom-Json
$reviewId = [IO.Path]::GetFileNameWithoutExtension($reviewPath)

$now = (Get-Date).ToUniversalTime().ToString('o')
$review.reviewId = $reviewId
$review.reference = $Reference
$review.scope = $Scope
$review.createdAt = $now
$review.updatedAt = $now
Write-ReviewJson -Review $review -Path $reviewPath

Write-Output $reviewPath
Write-Output "Commit '$repositoryRoot/.artifacts-temp/.gitignore'; JSON and HTML artifacts remain local."
