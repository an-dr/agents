#Requires -Version 7
<#
    Defines what an aligned Markdown table is. The formatter writes this form and
    the checker compares against it, so the two cannot disagree. Dot-source it.
#>

function Get-TableCell {
    <# Splits a table row into trimmed cells; an escaped pipe stays inside its cell. #>
    param([Parameter(Mandatory)][string]$Row)

    $body = $Row.Trim() -replace '^\|', '' -replace '(?<!\\)\|$', ''
    return @([regex]::Split($body, '(?<!\\)\|') | ForEach-Object { $_.Trim() })
}

function Get-CellWidth {
    <# Counts visible characters, so a combined character or an emoji counts once. #>
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)

    return [Globalization.StringInfo]::new($Text).LengthInTextElements
}

function Format-MarkdownTable {
    <# Returns one table block with its columns aligned; other pipe-only blocks return unchanged. #>
    param([Parameter(Mandatory)][string[]]$Rows)

    if ($Rows.Count -lt 2) { return $Rows }
    $separator = @(Get-TableCell -Row $Rows[1])
    if (@($separator | Where-Object { $_ -notmatch '^:?-+:?$' }).Count -gt 0) { return $Rows }

    $indent = [regex]::Match($Rows[0], '^\s*').Value
    $table = @($Rows | ForEach-Object { , @(Get-TableCell -Row $_) })

    $widths = [System.Collections.Generic.List[int]]::new()
    for ($rowIndex = 0; $rowIndex -lt $table.Count; $rowIndex++) {
        if ($rowIndex -eq 1) { continue }
        $cells = $table[$rowIndex]
        for ($column = 0; $column -lt $cells.Count; $column++) {
            $width = Get-CellWidth -Text $cells[$column]
            if ($column -ge $widths.Count) { $widths.Add([Math]::Max($width, 3)) }
            elseif ($width -gt $widths[$column]) { $widths[$column] = $width }
        }
    }
    while ($widths.Count -lt $separator.Count) { $widths.Add(3) }

    $result = for ($rowIndex = 0; $rowIndex -lt $table.Count; $rowIndex++) {
        $cells = $table[$rowIndex]
        $rendered = for ($column = 0; $column -lt $cells.Count; $column++) {
            $cell = $cells[$column]
            if ($rowIndex -eq 1) {
                $left = if ($cell.StartsWith(':')) { ':' } else { '' }
                $right = if ($cell.EndsWith(':')) { ':' } else { '' }
                $left + ('-' * ($widths[$column] - $left.Length - $right.Length)) + $right
            }
            else {
                $cell + (' ' * ($widths[$column] - (Get-CellWidth -Text $cell)))
            }
        }
        $indent + '| ' + (@($rendered) -join ' | ') + ' |'
    }
    return @($result)
}
