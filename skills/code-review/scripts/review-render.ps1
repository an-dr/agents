#Requires -Version 7
<# Renders canonical review JSON as deterministic Markdown. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ReviewPath,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Review.Common.psm1') -Force

function ConvertTo-MarkdownLine {
    param([AllowEmptyString()][string]$Value)

    $line = ($Value -replace '[\r\n]+', ' ').Trim().Replace('`', '``')
    return $line -replace '^([#>])', '\$1'
}

function Get-FindingSectionLines {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Notes
    )

    $sectionLines = [Collections.Generic.List[string]]::new()
    $sectionLines.Add("### $Title")
    $sectionLines.Add('')
    if ($Notes.Count -eq 0) {
        $sectionLines.Add('None.')
    }
    foreach ($note in $Notes) {
        $location = ConvertTo-MarkdownLine -Value $note.file
        if ($note.line) {
            $location = "${location}:$($note.line)"
        }
        $text = ConvertTo-MarkdownLine -Value $note.text
        $recommendation = ConvertTo-MarkdownLine -Value $note.recommendation
        $sectionLines.Add("- **$($note.id)** ``$location`` — $text Fix: $recommendation")
    }
    $sectionLines.Add('')
    return $sectionLines.ToArray()
}

$resolvedPath = Resolve-ReviewPath -Path $ReviewPath
$review = Read-ReviewJson -Path $resolvedPath
if (-not $OutputPath) {
    $OutputPath = [IO.Path]::ChangeExtension($resolvedPath, '.md')
}
elseif (-not [IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path (Get-Location) $OutputPath
}
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
if ((Split-Path -Parent $OutputPath) -ne (Split-Path -Parent $resolvedPath)) {
    throw 'Rendered Markdown must remain directly inside REPO/code-review/.'
}

$lines = [Collections.Generic.List[string]]::new()
$lines.Add("# Code review — $(ConvertTo-MarkdownLine -Value $review.reference)")
$lines.Add('')
$lines.Add("Scope: $($review.scope)")
$lines.Add("Review: $($review.reviewId)")
$lines.Add('')
$lines.Add('## Summary')
$lines.Add('')
$lines.Add($(if ($review.summary) { ConvertTo-MarkdownLine -Value $review.summary } else { 'Not set.' }))
$lines.Add('')
$lines.Add('## Findings')
$lines.Add('')
foreach ($line in Get-FindingSectionLines -Title 'Critical — must fix before merge' -Notes @($review.sections.critical)) { $lines.Add($line) }
foreach ($line in Get-FindingSectionLines -Title 'High' -Notes @($review.sections.high)) { $lines.Add($line) }
foreach ($line in Get-FindingSectionLines -Title 'Improvements' -Notes @($review.sections.improvements)) { $lines.Add($line) }
$lines.Add('## Positives')
$lines.Add('')
if (@($review.sections.positives).Count -eq 0) {
    $lines.Add('None recorded.')
}
foreach ($note in @($review.sections.positives)) {
    $lines.Add("- **$($note.id)** $(ConvertTo-MarkdownLine -Value $note.text)")
}
$lines.Add('')
$lines.Add('## Verdict')
$lines.Add('')
$lines.Add("**$($review.verdict.decision)** — $(ConvertTo-MarkdownLine -Value $review.verdict.rationale)")
$lines.Add('')

Write-ReviewText -Text ($lines -join [Environment]::NewLine) -Path $OutputPath
Write-Output $OutputPath
