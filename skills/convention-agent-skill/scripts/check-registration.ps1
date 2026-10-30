#Requires -Version 7
<#
    Checks that the agents repository describes its skills consistently:
    every skill folder is registered in skills/README.md, frontmatter names match folders, every skill declares
    the skills it names in metadata.dependencies (PROHIBITED forbids any, none
    allows none today), and no code lives outside skills/ except the root test
    runner. Dependency cycles are listed with their path.
    Prints a Markdown table of problems and exits 1 when there are any, or on a
    cycle when -FailOnCycle is given.
#>
[CmdletBinding()]
param(
    [string]$Root = (Join-Path $PSScriptRoot '../../..'),
    [switch]$FailOnCycle
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path -LiteralPath $Root).ProviderPath
$skillsDir = Join-Path $Root 'skills'
$problems = [System.Collections.Generic.List[object]]::new()
function Add-Problem([string]$Where, [string]$What) {
    $problems.Add([pscustomobject]@{ Where = $Where; What = $What })
}

function Get-SkillTable([string]$Path) {
    <# Reads the first column skill name and the use column of a skill table. #>
    $table = [ordered]@{}
    foreach ($line in [IO.File]::ReadAllLines($Path)) {
        if ($line -match '^\|\s*\[?`(?<name>[a-z0-9-]+)`\]?(\([^)]*\))?\s*\|\s*(?<use>.+?)\s*\|\s*$') {
            $table[$Matches['name']] = $Matches['use']
        }
    }
    return $table
}

function Get-Frontmatter([string]$Path) {
    <# Returns name, metadata.dependencies (raw string, or $null), and the body of a SKILL.md. #>
    $lines = [IO.File]::ReadAllLines($Path)
    $result = @{ name = $null; dependencies = $null; body = '' }
    if ($lines.Count -eq 0 -or $lines[0] -ne '---') { return $result }
    $inMetadata = $false
    $end = $lines.Count
    for ($i = 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -eq '---') { $end = $i; break }
        if ($line -match '^name:\s*(?<v>\S+)') { $result.name = $Matches['v'] }
        if ($line -match '^\S') { $inMetadata = $line -match '^metadata:\s*$' }
        if ($inMetadata -and $line -match '^\s+dependencies:\s*(?<v>.+)$') {
            $result.dependencies = $Matches['v'].Trim()
        }
    }
    if ($end + 1 -lt $lines.Count) { $result.body = ($lines[($end + 1)..($lines.Count - 1)] -join "`n") }
    return $result
}

function Find-DependencyCycle([hashtable]$Graph) {
    <# One shortest cycle through each skill that lies on a cycle, deduplicated by rotation. #>
    $cycles = @{}
    foreach ($start in ($Graph.Keys | Sort-Object)) {
        $queue = [System.Collections.Generic.Queue[object]]::new()
        $queue.Enqueue(@($start))
        $seen = @{ $start = $true }
        $found = $null
        while ($queue.Count -gt 0 -and -not $found) {
            $path = $queue.Dequeue()
            foreach ($next in $Graph[$path[-1]]) {
                if ($next -eq $start) { $found = $path; break }
                if (-not $seen.ContainsKey($next) -and $Graph.ContainsKey($next)) {
                    $seen[$next] = $true
                    $queue.Enqueue(@($path + $next))
                }
            }
        }
        if ($found) {
            $smallest = ($found | Sort-Object)[0]
            $rotate = [array]::IndexOf($found, $smallest)
            $ordered = @($found[$rotate..($found.Count - 1)]) + @(if ($rotate -gt 0) { $found[0..($rotate - 1)] })
            $cycles[($ordered -join ' -> ') + " -> $($ordered[0])"] = $true
        }
    }
    return @($cycles.Keys | Sort-Object)
}

# ---- registration ----------------------------------------------------------

$folders = @(Get-ChildItem -LiteralPath $skillsDir -Directory | Select-Object -ExpandProperty Name | Sort-Object)
$catalog = Get-SkillTable (Join-Path $skillsDir 'README.md')

foreach ($name in $folders) {
    if (-not $catalog.Contains($name)) { Add-Problem $name 'missing from the skills/README.md table' }
}
foreach ($name in $catalog.Keys) {
    if ($name -notin $folders) { Add-Problem $name 'listed in the skills/README.md table but has no folder' }
}

# ---- frontmatter and dependencies -----------------------------------------

$graph = @{}
foreach ($name in $folders) {
    $skillFile = Join-Path $skillsDir "$name/SKILL.md"
    if (-not (Test-Path -LiteralPath $skillFile)) { Add-Problem $name 'has no SKILL.md'; continue }
    $front = Get-Frontmatter $skillFile
    if ($front.name -cne $name) { Add-Problem $name "frontmatter name is '$($front.name)'" }

    $raw = $front.dependencies
    if ($null -eq $raw) { Add-Problem $name 'has no metadata.dependencies; declare the skills it names, or none, or PROHIBITED'; continue }
    $declared = if ($raw -ceq 'PROHIBITED' -or $raw -ceq 'none') { @() } else { @($raw -split '\s+') }
    foreach ($dependency in $declared) {
        if ($dependency -notin $folders) { Add-Problem $name "declares dependency '$dependency', which does not exist" }
    }
    $graph[$name] = @($declared | Where-Object { $_ -in $folders })

    # Every skill the instructions name is a dependency, passed folder or not.
    $mentioned = @($folders | Where-Object {
            $_ -ne $name -and $front.body -match ('(?<![\w-])' + [regex]::Escape($_) + '(?![\w-])')
        })
    foreach ($other in $mentioned) {
        if ($raw -ceq 'PROHIBITED') { Add-Problem "skills/$name/SKILL.md" "is PROHIBITED from depending on other skills but names $other" }
        elseif ($other -notin $declared) { Add-Problem "skills/$name/SKILL.md" "names $other but does not declare it in dependencies" }
    }
    foreach ($dependency in $declared) {
        if ($dependency -in $folders -and $dependency -notin $mentioned) {
            Add-Problem "skills/$name/SKILL.md" "declares $dependency but never names it"
        }
    }
}

$cycles = @(Find-DependencyCycle $graph)

# ---- paths and layout ------------------------------------------------------

foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -File -Include '*.md' |
        Where-Object { $_.FullName.Substring($Root.Length + 1) -notmatch '^(\.git|\.artifacts|node_modules)[\\/]' }) {
    $relative = $file.FullName.Substring($Root.Length + 1) -replace '\\', '/'
    $text = [IO.File]::ReadAllText($file.FullName)
    if ($text -match '(?<![<\w])agents/skills/' -or $text -match '<clone>/skills/') {
        Add-Problem $relative "uses a repository-layout path to a skill; write '<skill>/' or '<skill-name>/'"
    }
}

foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -File -Include '*.ps1', '*.psm1' |
        Where-Object { $_.FullName.Substring($Root.Length + 1) -notmatch '^(\.git|\.artifacts)[\\/]' }) {
    $relative = $file.FullName.Substring($Root.Length + 1) -replace '\\', '/'
    if ($relative -notlike 'skills/*' -and $relative -ne 'tests/run-all.ps1') {
        Add-Problem $relative 'code outside skills/; skills must stay self-contained'
    }
}

# ---- report ----------------------------------------------------------------

function Write-Cycle {
    if ($cycles.Count -eq 0) { return }
    Write-Output ''
    Write-Output "Dependency cycles ($($cycles.Count), shortest through each skill on one):"
    Write-Output ''
    foreach ($cycle in $cycles) { Write-Output "- ``$cycle``" }
}
$cycleFails = $FailOnCycle -and $cycles.Count -gt 0

if ($problems.Count -eq 0) {
    Write-Output "Registration check passed: $($folders.Count) skills, the skill table and dependencies agree."
    Write-Cycle
    if ($cycleFails) { exit 1 }
    exit 0
}
Write-Output "Registration check: $($problems.Count) problem(s)."
Write-Output ''
Write-Output '| Where | Problem |'
Write-Output '| --- | --- |'
foreach ($problem in $problems) {
    Write-Output "| ``$($problem.Where)`` | $($problem.What -replace '\|', '\|') |"
}
Write-Cycle
exit 1
