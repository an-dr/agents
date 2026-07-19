#Requires -Version 7
<# Creates a canonical JSON review in REPO/code-review/. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Reference,
    [Parameter(Mandatory)]
    [ValidateSet('verify', 'mr', 'requested')]
    [string]$Scope
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Review.Common.psm1') -Force

$repositoryRoot = Get-ReviewRepositoryRoot
$reviewDirectory = Initialize-ReviewDirectory -RepositoryRoot $repositoryRoot
$templatePath = Join-Path $PSScriptRoot '../assets/review-template.json'
$review = Get-Content -Raw -LiteralPath $templatePath | ConvertFrom-Json
$slug = ConvertTo-ReviewSlug -Value $Reference
$reviewId = '{0}-{1}-{2}' -f (
    (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd-HHmmssfffZ'),
    [guid]::NewGuid().ToString('N').Substring(0, 8),
    $slug
)
$reviewPath = Join-Path $reviewDirectory "$reviewId.review.json"
if (Test-Path -LiteralPath $reviewPath) {
    throw "Review already exists: $reviewPath"
}

$now = (Get-Date).ToUniversalTime().ToString('o')
$review.reviewId = $reviewId
$review.reference = $Reference
$review.scope = $Scope
$review.createdAt = $now
$review.updatedAt = $now
Write-ReviewJson -Review $review -Path $reviewPath

Write-Output $reviewPath
Write-Output "Commit '$reviewDirectory/.gitignore'; JSON and Markdown artifacts remain local."
