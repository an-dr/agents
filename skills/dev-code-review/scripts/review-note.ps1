#Requires -Version 7
<# Adds a numbered note or updates a singleton review section. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ReviewPath,
    [Parameter(Mandatory)]
    [ValidateSet('summary', 'critical', 'high', 'improvement', 'positive', 'verdict')]
    [string]$Section,
    [Parameter(Mandatory)][string]$Text,
    [string]$File,
    [ValidateRange(1, [int]::MaxValue)][int]$Line,
    [string]$Recommendation,
    [ValidateSet('approve', 'approve-with-comments', 'changes-required')]
    [string]$Decision
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Review.Common.psm1') -Force

function Get-NextNoteId {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Notes,
        [Parameter(Mandatory)][string]$Prefix
    )

    $maximum = 0
    foreach ($note in $Notes) {
        if ($note.id -match ('^{0}\.(\d+)$' -f [regex]::Escape($Prefix))) {
            $maximum = [Math]::Max($maximum, [int]$Matches[1])
        }
    }
    return "$Prefix.$($maximum + 1)"
}

$reviewLock = Enter-ReviewLock -Path $ReviewPath
try {
    $resolvedPath = Resolve-ReviewPath -Path $ReviewPath
    $review = Read-ReviewJson -Path $resolvedPath
    $noteId = $null

    switch ($Section) {
    'summary' {
        $review.summary = $Text
    }
    'verdict' {
        if (-not $Decision) {
            throw '-Decision is required for the verdict section.'
        }
        $review.verdict.decision = $Decision
        $review.verdict.rationale = $Text
    }
    'positive' {
        $notes = @($review.sections.positives)
        $noteId = Get-NextNoteId -Notes $notes -Prefix 'PO'
        $review.sections.positives = $notes + [pscustomobject]@{
            id      = $noteId
            text    = $Text
            addedAt = (Get-Date).ToUniversalTime().ToString('o')
        }
    }
    default {
        if ([string]::IsNullOrWhiteSpace($File) -or [string]::IsNullOrWhiteSpace($Recommendation)) {
            throw '-File and -Recommendation are required for findings.'
        }
        $definition = switch ($Section) {
            'critical' { @{ Collection = 'critical'; Prefix = 'CR' } }
            'high' { @{ Collection = 'high'; Prefix = 'HI' } }
            'improvement' { @{ Collection = 'improvements'; Prefix = 'IM' } }
        }
        $notes = @($review.sections.($definition.Collection))
        $noteId = Get-NextNoteId -Notes $notes -Prefix $definition.Prefix
        $normalizedFile = $File.Replace('\', '/')
        $review.sections.($definition.Collection) = $notes + [pscustomobject]@{
            id             = $noteId
            file           = $normalizedFile
            line           = if ($PSBoundParameters.ContainsKey('Line')) { $Line } else { $null }
            text           = $Text
            recommendation = $Recommendation
            addedAt        = (Get-Date).ToUniversalTime().ToString('o')
        }
    }
    }

    Write-ReviewJson -Review $review -Path $resolvedPath
    if ($noteId) {
        Write-Output "Added $noteId to $resolvedPath"
    }
    else {
        Write-Output "Updated $Section in $resolvedPath"
    }
}
finally {
    Exit-ReviewLock -Lock $reviewLock
}
