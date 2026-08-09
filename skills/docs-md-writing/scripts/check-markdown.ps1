#Requires -Version 7
<#
    Checks Markdown files against the docs-md-writing format rules.
    Exits non-zero on any error; hard wraps are warnings unless -FailOnWrap.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][string]$Path,
    [switch]$FailOnWrap
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-MarkdownViolation {
    <# Returns the rule violations found in one Markdown file. #>
    param([Parameter(Mandatory)][string]$File)

    $found = [System.Collections.Generic.List[object]]::new()
    $raw = [IO.File]::ReadAllText($File)
    $lines = @((($raw -replace "`r`n", "`n") -replace "`r", "`n") -split "`n")

    function Add-Violation {
        param([string]$Severity, [string]$Rule, [int]$Line, [string]$Detail)
        $found.Add([pscustomobject]@{
                Severity = $Severity; Rule = $Rule; Line = $Line; Detail = $Detail
            })
    }

    if (-not $raw.EndsWith("`n")) {
        Add-Violation error 'file.newline' $lines.Count 'The file does not end with a newline.'
    }
    elseif ($raw.EndsWith("`n`n")) {
        Add-Violation error 'file.newline' $lines.Count 'The file ends with more than one newline.'
    }

    $inFence = $false
    $headingCount = 0
    $previousLevel = 0
    $paragraphStart = -1
    $paragraphLines = 0

    # YAML frontmatter is not Markdown; skip past its closing fence.
    $start = 0
    if ($lines.Count -gt 0 -and $lines[0] -eq '---') {
        for ($index = 1; $index -lt $lines.Count; $index++) {
            if ($lines[$index] -eq '---') { $start = $index + 1; break }
        }
        if ($start -eq 0) {
            Add-Violation error 'frontmatter.unclosed' 1 'The frontmatter block is never closed.'
        }
    }

    for ($index = $start; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        $number = $index + 1
        $previous = if ($index -gt 0) { $lines[$index - 1] } else { '' }

        if ($line -match '^\s*```') {
            if (-not $inFence) {
                if ($line -notmatch '^\s*```[A-Za-z0-9]') {
                    Add-Violation error 'fence.language' $number 'The code fence names no language.'
                }
                if ($index -gt 0 -and $previous -ne '') {
                    Add-Violation error 'fence.blank' $number 'A blank line precedes a code fence.'
                }
            }
            $inFence = -not $inFence
            $paragraphStart = -1; $paragraphLines = 0
            continue
        }
        if ($inFence) { continue }

        if ($line -match '\s+$') {
            Add-Violation error 'line.trailing' $number 'The line carries trailing whitespace.'
        }
        if ($line -match '^__[^_]+__|(?<![A-Za-z0-9_])_[^_\s][^_]*_(?![A-Za-z0-9_])') {
            Add-Violation error 'emphasis.marker' $number 'Emphasis uses ** and *, never underscores.'
        }
        if ($line -match '\[(here|this|link)\]\(') {
            Add-Violation error 'link.text' $number 'Link text describes its target.'
        }

        if ($line -match '^(#{1,6})\s') {
            $level = $Matches[1].Length
            if ($level -eq 1) { $headingCount++ }
            if ($previousLevel -gt 0 -and $level -gt $previousLevel + 1) {
                Add-Violation error 'heading.level' $number "The heading jumps from level $previousLevel to $level."
            }
            if ($line -match '[.,;:!]\s*$') {
                Add-Violation error 'heading.punctuation' $number 'The heading ends with punctuation.'
            }
            if ($index -gt 0 -and $previous -ne '') {
                Add-Violation error 'heading.blank' $number 'A blank line precedes a heading.'
            }
            $previousLevel = $level
            $paragraphStart = -1; $paragraphLines = 0
            continue
        }

        if ($line -match '^\s*\|.*\|\s*$') {
            if ($line -match '\S\s{2,}\|') {
                Add-Violation error 'table.padding' $number 'The table pads columns to align them.'
            }
            $paragraphStart = -1; $paragraphLines = 0
            continue
        }

        if ($line -match '^\s*([-*+]|\d+\.)\s') {
            if ($line -match '^\s*[*+]\s') {
                Add-Violation error 'list.marker' $number 'Bullets use "-".'
            }
            $paragraphStart = -1; $paragraphLines = 0
            continue
        }

        # Prose spanning several lines is a hard wrap: one paragraph is one line.
        if ($line -eq '') {
            if ($paragraphLines -gt 1) {
                Add-Violation warning 'line.wrap' $paragraphStart "The paragraph is hard-wrapped across $paragraphLines lines."
            }
            $paragraphStart = -1; $paragraphLines = 0
        }
        else {
            if ($paragraphStart -lt 0) { $paragraphStart = $number }
            $paragraphLines++
        }
    }

    if ($paragraphLines -gt 1) {
        Add-Violation warning 'line.wrap' $paragraphStart "The paragraph is hard-wrapped across $paragraphLines lines."
    }
    if ($inFence) {
        Add-Violation error 'fence.unclosed' $lines.Count 'A code fence is never closed.'
    }
    if ($headingCount -gt 1) {
        Add-Violation error 'heading.single' 1 "The file holds $headingCount level-one headings; it takes one."
    }

    return $found
}

$files = @(
    if (Test-Path -LiteralPath $Path -PathType Container) {
        Get-ChildItem -LiteralPath $Path -Recurse -File -Filter '*.md' |
            Where-Object { $_.FullName -notmatch '\\(\.git|node_modules)\\' }
    }
    else {
        Get-Item -LiteralPath $Path
    }
)
if ($files.Count -eq 0) { throw "No Markdown files found at '$Path'." }

$errorTotal = 0
$warningTotal = 0
foreach ($file in $files) {
    $violations = @(Get-MarkdownViolation -File $file.FullName)
    if ($FailOnWrap) {
        foreach ($item in $violations) {
            if ($item.Rule -eq 'line.wrap') { $item.Severity = 'error' }
        }
    }
    $errors = @($violations | Where-Object { $_.Severity -eq 'error' })
    $errorTotal += $errors.Count
    $warningTotal += $violations.Count - $errors.Count
    if ($violations.Count -eq 0) { continue }

    Write-Output $file.FullName
    foreach ($item in ($violations | Sort-Object Line)) {
        Write-Output ('  {0,-7} line {1,-4} {2,-20} {3}' -f
            $item.Severity, $item.Line, $item.Rule, $item.Detail)
    }
}

Write-Output ''
Write-Output "$($files.Count) file(s) checked, $errorTotal error(s), $warningTotal warning(s)."
if ($errorTotal -gt 0) { exit 1 }
