#Requires -Version 7
<#
    Formats Markdown files: aligns tables, removes trailing whitespace, and ends the
    file with one newline. Frontmatter, code fences, and HTML comments stay untouched.
    Refuses to write a file whose text would change, so content cannot be lost.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][string[]]$Path,
    [switch]$WhatIfOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'markdown-table.ps1')

function Get-FormattedLine {
    <# Returns the file's lines in their formatted form. #>
    param([Parameter(Mandatory)][AllowEmptyString()][AllowEmptyCollection()][string[]]$Lines)

    $output = [System.Collections.Generic.List[string]]::new()
    $index = 0

    if ($Lines.Count -gt 0 -and $Lines[0] -eq '---') {
        $output.Add($Lines[0])
        for ($index = 1; $index -lt $Lines.Count; $index++) {
            $output.Add($Lines[$index])
            if ($Lines[$index] -eq '---') { $index++; break }
        }
    }

    $inFence = $false
    $inComment = $false
    while ($index -lt $Lines.Count) {
        $line = $Lines[$index]

        if ($inFence -or $line -match '^\s*```') {
            if ($line -match '^\s*```') { $inFence = -not $inFence }
            $output.Add($line)
            $index++
            continue
        }
        if ($inComment -or $line -match '^\s*<!--') {
            $inComment = $line -notmatch '-->'
            $output.Add($line)
            $index++
            continue
        }
        if ($line -match '^\s*\|.*\|\s*$') {
            $rows = [System.Collections.Generic.List[string]]::new()
            while ($index -lt $Lines.Count -and $Lines[$index] -match '^\s*\|.*\|\s*$') {
                $rows.Add($Lines[$index])
                $index++
            }
            foreach ($row in (Format-MarkdownTable -Rows $rows.ToArray())) { $output.Add($row.TrimEnd()) }
            continue
        }

        $output.Add($line.TrimEnd())
        $index++
    }
    return $output.ToArray()
}

function Get-TextSignature {
    <# Removes everything the formatter may change: whitespace and separator dashes. #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    return ($Text -replace '\s+', '' -replace '-+', '-')
}

$files = @(
    foreach ($targetPath in $Path) {
        if (Test-Path -LiteralPath $targetPath -PathType Container) {
            Get-ChildItem -LiteralPath $targetPath -Recurse -File -Filter '*.md' |
                Where-Object { $_.FullName -notmatch '[\\/](\.git|node_modules)[\\/]' }
        }
        else { Get-Item -LiteralPath $targetPath }
    }
)
$files = @($files | Sort-Object FullName -Unique)
if ($files.Count -eq 0) { throw "No Markdown files found at '$Path'." }

$changed = 0
foreach ($file in $files) {
    $original = [IO.File]::ReadAllText($file.FullName)
    $lines = @((($original -replace "`r`n", "`n") -replace "`r", "`n") -split "`n")
    $formatted = ((Get-FormattedLine -Lines $lines) -join "`n").TrimEnd() + "`n"

    # Keep the file's own line endings, so a no-op run rewrites nothing.
    if ($original.Contains("`r`n")) { $formatted = $formatted -replace "`n", "`r`n" }

    if ((Get-TextSignature -Text $original) -ne (Get-TextSignature -Text $formatted)) {
        throw "Formatting '$($file.FullName)' would change its text; nothing was written."
    }
    if ($formatted -ceq $original) { continue }

    $changed++
    Write-Output $file.FullName
    if (-not $WhatIfOnly) {
        [IO.File]::WriteAllText($file.FullName, $formatted, [Text.UTF8Encoding]::new($false))
    }
}

Write-Output ''
$verb = if ($WhatIfOnly) { 'would change' } else { 'changed' }
Write-Output "$($files.Count) file(s) checked, $changed $verb."
