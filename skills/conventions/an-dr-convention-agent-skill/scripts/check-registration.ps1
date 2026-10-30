#Requires -Version 7
<#
    Checks that a repository describes its skills consistently: every skill sits one
    level below a category folder (actions, concepts, conventions, or a folder whose
    name starts with an underscore for skills of the repository itself), is registered
    in skills/README.md, has a name matching its folder and, for a concept or
    convention, containing its type, declares its an-dr.type and an-dr.dependencies, agrees with its folder
    on its type, names only the skills it declares (PROHIBITED forbids any, none
    allows none today), and never depends on a skill of the repository's own folder
    unless it lives there. Dependency cycles are listed with their path, and concept
    skills hold nothing but SKILL.md.
    Prints a Markdown table of problems and exits 1 when there are any, or on a
    cycle when -FailOnCycle is given.
#>
[CmdletBinding()]
param(
    [string]$Root = (Join-Path $PSScriptRoot '../../../..'),
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
    <# Returns name, the metadata an-dr.* values (raw strings, or $null), and the body of a SKILL.md. #>
    $lines = [IO.File]::ReadAllLines($Path)
    $result = @{ name = $null; type = $null; dependencies = $null; body = '' }
    if ($lines.Count -eq 0 -or $lines[0] -ne '---') { return $result }
    $inMetadata = $false
    $end = $lines.Count
    for ($i = 1; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -eq '---') { $end = $i; break }
        if ($line -match '^name:\s*(?<v>\S+)') { $result.name = $Matches['v'] }
        if ($line -match '^\S') { $inMetadata = $line -match '^metadata:\s*$' }
        if ($inMetadata -and $line -match '^\s+an-dr\.dependencies:\s*(?<v>.+)$') { $result.dependencies = $Matches['v'].Trim() }
        if ($inMetadata -and $line -match '^\s+an-dr\.type:\s*(?<v>.+)$') { $result.type = $Matches['v'].Trim() }
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

$categories = @{ 'actions' = 'action'; 'concepts' = 'concept'; 'conventions' = 'convention' }
# A folder whose name starts with an underscore holds the repository's own skills, of any type.
function Test-OwnCategory([string]$Category) { return $Category.StartsWith('_') }
$catalog = Get-SkillTable (Join-Path $skillsDir 'README.md')

# Every skill is skills/<category>/<name>/SKILL.md; nothing else holds a skill.
$skillPaths = @{}
foreach ($category in Get-ChildItem -LiteralPath $skillsDir -Directory | Sort-Object Name) {
    if (Test-Path -LiteralPath (Join-Path $category.FullName 'SKILL.md')) {
        Add-Problem "skills/$($category.Name)" 'holds a SKILL.md directly; skills sit one level deeper, inside a category folder'
        continue
    }
    if (-not $categories.ContainsKey($category.Name) -and -not (Test-OwnCategory $category.Name)) {
        Add-Problem "skills/$($category.Name)" "is not a category folder; use $($categories.Keys -join ', '), or a folder starting with '_' for the repository's own skills"
        continue
    }
    foreach ($directory in Get-ChildItem -LiteralPath $category.FullName -Directory | Sort-Object Name) {
        if ($skillPaths.ContainsKey($directory.Name)) {
            Add-Problem $directory.Name "exists in both $($skillPaths[$directory.Name].Category) and $($category.Name)"
            continue
        }
        $skillPaths[$directory.Name] = @{ Category = $category.Name; Path = $directory.FullName }
    }
}
$folders = @($skillPaths.Keys | Sort-Object)

foreach ($name in $folders) {
    if (-not $catalog.Contains($name)) { Add-Problem $name 'missing from the skills/README.md table' }
}
foreach ($name in $catalog.Keys) {
    if ($name -notin $folders) { Add-Problem $name 'listed in the skills/README.md table but has no folder' }
}

# ---- frontmatter and dependencies -----------------------------------------

$graph = @{}
foreach ($name in $folders) {
    $category = $skillPaths[$name].Category
    $skillFile = Join-Path $skillPaths[$name].Path 'SKILL.md'
    $where = "skills/$category/$name/SKILL.md"
    if (-not (Test-Path -LiteralPath $skillFile)) { Add-Problem "skills/$category/$name" 'has no SKILL.md'; continue }
    $front = Get-Frontmatter $skillFile
    if ($front.name -cne $name) { Add-Problem $where "frontmatter name is '$($front.name)'" }

    # Type: declared, valid, and in agreement with the folder and the name prefix.
    $type = $front.type
    if ($type -cnotin @('action', 'concept', 'convention')) { Add-Problem $where "metadata an-dr.type is '$type'; use action, concept, or convention" }
    else {
        $folderType = $categories[$category]
        if ($folderType -and $type -cne $folderType) { Add-Problem $where "is a $type but sits in $category, which holds ${folderType}s" }
        if (-not (Test-OwnCategory $category)) {
            if ($type -ceq 'concept' -and $name -cnotmatch '(^|-)concept-') { Add-Problem $where "is a concept, so its name needs 'concept-'" }
            if ($type -ceq 'convention' -and $name -cnotmatch '(^|-)convention-') { Add-Problem $where "is a convention, so its name needs 'convention-'" }
        }
        if ($type -ceq 'concept') {
            $extra = @(Get-ChildItem -LiteralPath $skillPaths[$name].Path -Force | Where-Object Name -cne 'SKILL.md')
            if ($extra.Count -gt 0) { Add-Problem $where "is a concept and holds $($extra[0].Name); a concept holds only SKILL.md" }
        }
    }

    $raw = $front.dependencies
    if ($null -eq $raw) { Add-Problem $where 'has no metadata an-dr.dependencies; declare the skills it names, or none, or PROHIBITED'; continue }
    $declared = if ($raw -ceq 'PROHIBITED' -or $raw -ceq 'none') { @() } else { @($raw -split '\s+') }
    foreach ($dependency in $declared) {
        if ($dependency -notin $folders) { Add-Problem $where "declares dependency '$dependency', which does not exist" }
    }
    $graph[$name] = @($declared | Where-Object { $_ -in $folders })

    # A skill outside the agents repository's own folder never depends on one inside it.
    if (-not (Test-OwnCategory $category)) {
        foreach ($dependency in $graph[$name]) {
            if (Test-OwnCategory $skillPaths[$dependency].Category) {
                Add-Problem $where "depends on $dependency, a skill of the repository itself; only skills in a '_' folder may"
            }
        }
    }

    # Every skill the instructions name, in backticks or as <name>, is a dependency, passed folder or not.
    $mentioned = @($folders | Where-Object {
            $_ -ne $name -and $front.body -match ('(`' + [regex]::Escape($_) + '`|<' + [regex]::Escape($_) + '>)')
        })
    foreach ($other in $mentioned) {
        if ($raw -ceq 'PROHIBITED') { Add-Problem $where "is PROHIBITED from depending on other skills but names $other" }
        elseif ($other -notin $declared) { Add-Problem $where "names $other but does not declare it in dependencies" }
    }
    foreach ($dependency in $declared) {
        if ($dependency -in $folders -and $dependency -notin $mentioned) {
            Add-Problem $where "declares $dependency but never names it"
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
