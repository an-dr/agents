#Requires -Version 7
<#
    Checks agent instructions for broken references and reports context cost.
    Exits non-zero when any reference does not resolve.
#>
[CmdletBinding()]
param([string]$Path = '.')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $Path).Path
$findings = [System.Collections.Generic.List[object]]::new()

function Add-Finding {
    param([string]$File, [int]$Line, [string]$Rule, [string]$Detail)
    $findings.Add([pscustomobject]@{ File = $File; Line = $Line; Rule = $Rule; Detail = $Detail })
}

function Get-RelativePath {
    param([string]$Full)
    return $Full.Replace($root, '').TrimStart('\', '/').Replace('\', '/')
}

function Get-FrontmatterName {
    <# Returns the frontmatter name of a Markdown file, or an empty string. #>
    param([string]$File)

    foreach ($line in (Get-Content -LiteralPath $File -TotalCount 10)) {
        if ($line -match '^name:\s*(\S+)\s*$') { return $Matches[1] }
    }
    return ''
}

$excluded = '\\(\.git|\.artifacts|node_modules)\\'
$skillFiles = @(Get-ChildItem $root -Recurse -File -Filter 'SKILL.md' | Where-Object { $_.FullName -notmatch $excluded })
$policyPath = Join-Path $root 'AGENTS.md'

# Every skill's frontmatter name matches its directory.
foreach ($manifest in $skillFiles) {
    $name = Get-FrontmatterName -File $manifest.FullName
    if ($name -ne $manifest.Directory.Name) {
        Add-Finding (Get-RelativePath $manifest.FullName) 2 'skill.name' "The frontmatter name '$name' does not match directory '$($manifest.Directory.Name)'."
    }
}

# Relative links must resolve.
$sources = @(Get-ChildItem $root -Recurse -File -Include '*.md', '*.ps1', '*.psm1' |
        Where-Object { $_.FullName -notmatch $excluded })
foreach ($source in $sources) {
    $relative = Get-RelativePath $source.FullName
    $lines = @([IO.File]::ReadAllLines($source.FullName))
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        $number = $index + 1

        if ($source.Extension -ne '.md') { continue }
        foreach ($match in [regex]::Matches($line, '\]\((?<target>[^)]+)\)')) {
            $target = $match.Groups['target'].Value
            if ($target -match '^(https?:|mailto:|#)') { continue }
            $cleaned = ($target -split '#')[0]
            if (-not $cleaned) { continue }
            $resolved = Join-Path $source.DirectoryName $cleaned
            if (-not (Test-Path -LiteralPath $resolved)) {
                Add-Finding $relative $number 'reference.link' "Link target '$cleaned' does not resolve."
            }
        }
    }
}

foreach ($finding in ($findings | Sort-Object File, Line)) {
    Write-Output ('{0,-44} line {1,-4} {2,-22} {3}' -f
        $finding.File, $finding.Line, $finding.Rule, $finding.Detail)
}

# Context cost, worst first. Four bytes per token is a rough working estimate.
Write-Output ''
Write-Output 'Context cost (approximate tokens):'
$measured = @(
    foreach ($file in @($policyPath, (Join-Path $root 'CLAUDE.md')) + @($skillFiles | ForEach-Object { $_.FullName })) {
        if ($file -and (Test-Path -LiteralPath $file)) {
            $size = (Get-Item -LiteralPath $file).Length
            [pscustomobject]@{ File = (Get-RelativePath $file); Bytes = $size; Tokens = [math]::Round($size / 4) }
        }
    }
)
foreach ($item in ($measured | Sort-Object Tokens -Descending | Select-Object -First 10)) {
    Write-Output ('  {0,-46} {1,7} tokens' -f $item.File, $item.Tokens)
}
Write-Output ('  {0,-46} {1,7} tokens total across {2} file(s)' -f '', ($measured | Measure-Object Tokens -Sum).Sum, $measured.Count)

Write-Output ''
Write-Output "$($findings.Count) broken reference(s)."
if ($findings.Count -gt 0) { exit 1 }
