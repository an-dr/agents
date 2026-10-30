#Requires -Version 7
<#
.SYNOPSIS
    Builds the dependency graph of a repository's skills from their an-dr.dependencies
    declarations, as a Mermaid flowchart, and marks every skill that declares none.

.DESCRIPTION
    Skills sit in skills/<category>/<name>/SKILL.md. Each category becomes a group in
    the diagram, and each name in a skill's an-dr.dependencies becomes an arrow.
    A skill whose frontmatter has no an-dr.dependencies key is drawn dashed and listed
    after the diagram. none and PROHIBITED declare no arrows.

    Without -Markdown the diagram is printed. With -Markdown the diagram replaces the
    block between <!-- skill-dependencies begin --> and <!-- skill-dependencies end -->
    in that file. -Check changes nothing: it exits 1 when that block is stale or any
    skill lacks the key.
#>
[CmdletBinding()]
param(
    [string]$Root = (Join-Path $PSScriptRoot '../../../..'),
    [string]$Markdown,
    [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path -LiteralPath $Root).ProviderPath
$begin = '<!-- skill-dependencies begin -->'
$end = '<!-- skill-dependencies end -->'

function Get-Dependency([string]$Path) {
    <# Returns the declared dependency names, or $null when the skill declares none at all. #>
    $inMetadata = $false
    $lines = [IO.File]::ReadAllLines($Path)
    for ($i = 1; $i -lt $lines.Count -and $lines[$i] -ne '---'; $i++) {
        if ($lines[$i] -match '^\S') { $inMetadata = $lines[$i] -match '^metadata:\s*$' }
        if ($inMetadata -and $lines[$i] -match '^\s+an-dr\.dependencies:\s*(?<v>.+)$') {
            $value = $Matches['v'].Trim()
            if ($value -ceq 'none' -or $value -ceq 'PROHIBITED') { return , @() }
            return , @($value -split '\s+')
        }
    }
    return $null
}

$skills = @(foreach ($file in Get-ChildItem -Path (Join-Path $Root 'skills/*/*/SKILL.md') | Sort-Object FullName) {
        [pscustomobject]@{ Name = $file.Directory.Name; Category = $file.Directory.Parent.Name; Dependencies = Get-Dependency $file.FullName }
    })
if ($skills.Count -eq 0) { throw "No skills found under $Root/skills/<category>/<name>/SKILL.md." }

$known = @($skills | ForEach-Object Name)
$undeclared = @($skills | Where-Object { $null -eq $_.Dependencies })
$unknown = @(foreach ($skill in $skills) { foreach ($d in @($skill.Dependencies)) { if ($d -and $d -notin $known) { "$($skill.Name) -> $d" } } })

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add('```mermaid')
$lines.Add('flowchart LR')
foreach ($category in ($skills | ForEach-Object Category | Sort-Object -Unique)) {
    $title = (($category.TrimStart('_') -replace '-', ' '))
    $title = $title.Substring(0, 1).ToUpperInvariant() + $title.Substring(1)
    $id = 'g_' + ($category.TrimStart('_') -replace '[^A-Za-z0-9]', '_')
    $lines.Add("    subgraph $id[`"$title`"]")
    foreach ($skill in ($skills | Where-Object Category -eq $category)) { $lines.Add("        $($skill.Name)") }
    $lines.Add('    end')
}
foreach ($skill in $skills) {
    if ($null -ne $skill.Dependencies -and @($skill.Dependencies).Count -gt 0) {
        $lines.Add("    $($skill.Name) --> " + (($skill.Dependencies | Where-Object { $_ -in $known }) -join ' & '))
    }
}
if ($undeclared.Count -gt 0) {
    $lines.Add('    classDef undeclared stroke-dasharray: 5 3')
    $lines.Add('    class ' + (($undeclared | ForEach-Object Name) -join ',') + ' undeclared')
}
$lines.Add('```')
$diagram = $lines -join "`n"
$edges = (@($skills | Where-Object { $null -ne $_.Dependencies } | ForEach-Object { @($_.Dependencies).Count } | Measure-Object -Sum).Sum)

function Write-Summary {
    Write-Output "Dependency graph: $($skills.Count) skills, $edges arrows."
    if ($undeclared.Count -gt 0) {
        Write-Output ''
        Write-Output "Skills without an-dr.dependencies ($($undeclared.Count)), drawn dashed:"
        Write-Output ''
        foreach ($skill in $undeclared) { Write-Output "- ``$($skill.Name)``" }
    }
    if ($unknown.Count -gt 0) {
        Write-Output ''
        Write-Output 'Declared dependencies that match no skill:'
        Write-Output ''
        foreach ($item in $unknown) { Write-Output "- ``$item``" }
    }
}

if (-not $Markdown) {
    Write-Output $diagram
    Write-Output ''
    Write-Summary
    if ($Check -and ($undeclared.Count -gt 0 -or $unknown.Count -gt 0)) { exit 1 }
    exit 0
}

$target = (Resolve-Path -LiteralPath $Markdown).ProviderPath
$text = [IO.File]::ReadAllText($target)
$pattern = [regex]::Escape($begin) + '[\s\S]*?' + [regex]::Escape($end)
if ($text -notmatch $pattern) {
    throw "$target has no '$begin' ... '$end' block; add the two markers where the diagram belongs."
}
$block = "$begin`n`n$diagram`n`n$end"
$updated = [regex]::Replace($text, $pattern, { param($m) $block })

if ($Check) {
    $stale = $updated -cne $text
    if ($stale) { Write-Output "The diagram in $target is stale; run this script with -Markdown to rebuild it." }
    Write-Summary
    if ($stale -or $undeclared.Count -gt 0 -or $unknown.Count -gt 0) { exit 1 }
    Write-Output "The diagram in $target is current."
    exit 0
}

if ($updated -cne $text) { [IO.File]::WriteAllText($target, $updated, [Text.UTF8Encoding]::new($false)) }
Write-Output "Rebuilt the dependency diagram in $target."
Write-Summary
