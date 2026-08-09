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

$skillsRoot = Join-Path $root 'skills'
$agentsRoot = Join-Path $root 'agents'
$skills = @(if (Test-Path $skillsRoot) { Get-ChildItem $skillsRoot -Directory })
$roles = @(if (Test-Path $agentsRoot) { Get-ChildItem $agentsRoot -File -Filter '*.md' })

$policyPath = Join-Path $root 'AGENTS.md'
$policyText = if (Test-Path $policyPath) { [IO.File]::ReadAllText($policyPath) } else { '' }
$indexPath = Join-Path $skillsRoot 'README.md'
$indexText = if (Test-Path $indexPath) { [IO.File]::ReadAllText($indexPath) } else { '' }

# Every skill needs a SKILL.md whose name matches its directory and appears in both tables.
foreach ($skill in $skills) {
    $manifest = Join-Path $skill.FullName 'SKILL.md'
    if (-not (Test-Path $manifest)) {
        Add-Finding (Get-RelativePath $skill.FullName) 0 'skill.manifest' 'The skill has no SKILL.md.'
        continue
    }
    $name = Get-FrontmatterName -File $manifest
    if ($name -ne $skill.Name) {
        Add-Finding (Get-RelativePath $manifest) 2 'skill.name' "The frontmatter name '$name' does not match directory '$($skill.Name)'."
    }
    if ($policyText -and $policyText -notmatch [regex]::Escape($skill.Name)) {
        Add-Finding 'AGENTS.md' 0 'skill.unregistered' "Skill '$($skill.Name)' is missing from the AGENTS.md skill table."
    }
    if ($indexText -and $indexText -notmatch [regex]::Escape($skill.Name)) {
        Add-Finding 'skills/README.md' 0 'skill.unregistered' "Skill '$($skill.Name)' is missing from the skills index."
    }
}

# Every role file needs a matching name and a row in the roles table.
foreach ($role in $roles) {
    $expected = [IO.Path]::GetFileNameWithoutExtension($role.Name)
    $name = Get-FrontmatterName -File $role.FullName
    if ($name -ne $expected) {
        Add-Finding (Get-RelativePath $role.FullName) 2 'role.name' "The frontmatter name '$name' does not match file '$expected'."
    }
    if ($policyText -and $policyText -notmatch "\|\s*``$([regex]::Escape($expected))``\s*\|") {
        Add-Finding 'AGENTS.md' 0 'role.unregistered' "Role '$expected' is missing from the roles table."
    }
}

# Referenced skills, roles, and relative links must resolve.
$sources = @(Get-ChildItem $root -Recurse -File -Include '*.md', '*.ps1', '*.psm1' |
        Where-Object { $_.FullName -notmatch '\\(\.git|node_modules)\\' })
foreach ($source in $sources) {
    $relative = Get-RelativePath $source.FullName
    $lines = @([IO.File]::ReadAllLines($source.FullName))
    for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        $number = $index + 1

        foreach ($match in [regex]::Matches($line, 'skills/(?<name>[a-z0-9][a-z0-9-]*)/')) {
            $name = $match.Groups['name'].Value
            if (-not (Test-Path (Join-Path $skillsRoot $name))) {
                Add-Finding $relative $number 'reference.skill' "Skill '$name' does not exist."
            }
        }
        foreach ($match in [regex]::Matches($line, '(?<![\w/])agents/(?<name>[a-z0-9][a-z0-9-]*)\.md')) {
            $name = $match.Groups['name'].Value
            if (-not (Test-Path (Join-Path $agentsRoot "$name.md"))) {
                Add-Finding $relative $number 'reference.role' "Role file '$name.md' does not exist."
            }
        }
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
    foreach ($file in @($policyPath, (Join-Path $root 'CLAUDE.md')) + $roles.FullName + ($skills | ForEach-Object { Join-Path $_.FullName 'SKILL.md' })) {
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
