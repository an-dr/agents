#Requires -Version 7
<#
    Joins hard-wrapped paragraphs and list items back onto single lines.
    Refuses to write a file whose words would change, so content cannot be lost.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][string]$Path,
    [switch]$WhatIfOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ReflowedText {
    <# Returns the file's content with wrapped paragraphs and list items joined. #>
    param([Parameter(Mandatory)][AllowEmptyString()][AllowEmptyCollection()][string[]]$Lines)

    $output = [System.Collections.Generic.List[string]]::new()
    $buffer = [System.Collections.Generic.List[string]]::new()
    $inFence = $false
    $index = 0

    function Complete-Buffer {
        if ($buffer.Count -gt 0) {
            $output.Add(($buffer -join ' '))
            $buffer.Clear()
        }
    }

    # Frontmatter is copied through untouched.
    if ($Lines.Count -gt 0 -and $Lines[0] -eq '---') {
        $output.Add($Lines[0])
        for ($index = 1; $index -lt $Lines.Count; $index++) {
            $output.Add($Lines[$index])
            if ($Lines[$index] -eq '---') { $index++; break }
        }
    }

    for (; $index -lt $Lines.Count; $index++) {
        $line = $Lines[$index]

        if ($line -match '^\s*```') {
            Complete-Buffer
            $output.Add($line)
            $inFence = -not $inFence
            continue
        }
        if ($inFence) { $output.Add($line); continue }

        # Structural lines stand alone and end whatever was being collected.
        if ($line -eq '' -or $line -match '^#{1,6}\s' -or $line -match '^\s*\|' -or
            $line -match '^\s*(-{3,}|\*{3,}|_{3,})\s*$' -or $line -match '^\s*>') {
            Complete-Buffer
            $output.Add($line)
            continue
        }

        # A new list item starts its own buffer; its continuation lines join it.
        if ($line -match '^\s*([-*+]|\d+[.)])\s') {
            Complete-Buffer
            $buffer.Add($line.TrimEnd())
            continue
        }

        $buffer.Add($line.Trim())
    }
    Complete-Buffer

    return ($output -join "`n")
}

function Get-WordSignature {
    <# Collapses text to its words, so only wrapping may differ. #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    return (($Text -replace '\s+', ' ')).Trim()
}

$files = @(
    if (Test-Path -LiteralPath $Path -PathType Container) {
        Get-ChildItem -LiteralPath $Path -Recurse -File -Filter '*.md' |
            Where-Object { $_.FullName -notmatch '\\(\.git|node_modules)\\' }
    }
    else { Get-Item -LiteralPath $Path }
)
if ($files.Count -eq 0) { throw "No Markdown files found at '$Path'." }

$changed = 0
foreach ($file in $files) {
    $original = [IO.File]::ReadAllText($file.FullName)
    $lines = @((($original -replace "`r`n", "`n") -replace "`r", "`n") -split "`n")
    $reflowed = (Get-ReflowedText -Lines $lines).TrimEnd() + "`n"

    # Keep the file's own line endings, so a no-op run rewrites nothing.
    if ($original.Contains("`r`n")) { $reflowed = $reflowed -replace "`n", "`r`n" }

    if ((Get-WordSignature -Text $original) -ne (Get-WordSignature -Text $reflowed)) {
        throw "Reflowing '$($file.FullName)' would change its words; nothing was written."
    }
    if ($reflowed -eq $original) { continue }

    $changed++
    Write-Output $file.FullName
    if (-not $WhatIfOnly) {
        [IO.File]::WriteAllText($file.FullName, $reflowed, [Text.UTF8Encoding]::new($false))
    }
}

Write-Output ''
$verb = if ($WhatIfOnly) { 'would change' } else { 'changed' }
Write-Output "$($files.Count) file(s) checked, $changed $verb."
