#Requires -Version 7
<#
    Checks that the agents repository describes its skills consistently:
    every skill folder is registered in AGENTS.md and skills/README.md with
    the same one-line use, frontmatter names match folders, scripts never
    guess another skill's location, passed skills are declared with no cycles, and no
    code lives outside skills/ except the root test runner.
    Prints a Markdown table of problems and exits 1 when there are any.
#>
[CmdletBinding()]
param([string]$Root = (Join-Path $PSScriptRoot '../../..'))

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
    <# Returns name and metadata.requires from a SKILL.md frontmatter. #>
    $lines = [IO.File]::ReadAllLines($Path)
    $result = @{ name = $null; requires = @() }
    if ($lines.Count -eq 0 -or $lines[0] -ne '---') { return $result }
    $inMetadata = $false
    for ($i = 1; $i -lt $lines.Count -and $lines[$i] -ne '---'; $i++) {
        $line = $lines[$i]
        if ($line -match '^name:\s*(?<v>\S+)') { $result.name = $Matches['v'] }
        if ($line -match '^\S') { $inMetadata = $line -match '^metadata:\s*$' }
        if ($inMetadata -and $line -match '^\s+requires:\s*(?<v>.+)$') {
            $result.requires = @($Matches['v'].Trim() -split '\s+')
        }
    }
    return $result
}

# ---- registration ----------------------------------------------------------

$folders = @(Get-ChildItem -LiteralPath $skillsDir -Directory | Select-Object -ExpandProperty Name | Sort-Object)
$policy = Get-SkillTable (Join-Path $Root 'AGENTS.md')
$catalog = Get-SkillTable (Join-Path $skillsDir 'README.md')

foreach ($name in $folders) {
    if (-not $policy.Contains($name)) { Add-Problem $name 'missing from the AGENTS.md skill table' }
    if (-not $catalog.Contains($name)) { Add-Problem $name 'missing from the skills/README.md table' }
    if ($policy.Contains($name) -and $catalog.Contains($name) -and $policy[$name] -cne $catalog[$name]) {
        Add-Problem $name 'one-line use differs between AGENTS.md and skills/README.md'
    }
}
foreach ($name in @($policy.Keys) + @($catalog.Keys) | Sort-Object -Unique) {
    if ($name -notin $folders) { Add-Problem $name 'listed in a skill table but has no folder' }
}

# ---- frontmatter and dependencies -----------------------------------------

$requires = @{}
foreach ($name in $folders) {
    $skillFile = Join-Path $skillsDir "$name/SKILL.md"
    if (-not (Test-Path -LiteralPath $skillFile)) { Add-Problem $name 'has no SKILL.md'; continue }
    $front = Get-Frontmatter $skillFile
    if ($front.name -cne $name) { Add-Problem $name "frontmatter name is '$($front.name)'" }
    $requires[$name] = $front.requires
    foreach ($dependency in $front.requires) {
        if ($dependency -notin $folders) { Add-Problem $name "requires '$dependency', which does not exist" }
    }
}

# A script never guesses where another skill is installed; the agent passes its folder.
$siblingPattern = '\.\./\.\./(?<skill>[a-z0-9-]+)'
foreach ($file in Get-ChildItem -LiteralPath $skillsDir -Recurse -File -Include '*.ps1', '*.psm1') {
    $relative = $file.FullName.Substring($Root.Length + 1) -replace '\\', '/'
    foreach ($match in [regex]::Matches([IO.File]::ReadAllText($file.FullName), $siblingPattern)) {
        $target = $match.Groups['skill'].Value
        if ($target -in $folders) {
            Add-Problem $relative "guesses where $target is installed; take its folder as a -<Name>Skill parameter"
        }
    }
}

# Every other skill's folder a SKILL.md command passes, as <skill-name>, is declared.
foreach ($name in $folders) {
    $skillFile = Join-Path $skillsDir "$name/SKILL.md"
    if (-not (Test-Path -LiteralPath $skillFile)) { continue }
    $used = [regex]::Matches([IO.File]::ReadAllText($skillFile), '-\w+Skill\s+<(?<skill>[a-z0-9-]+)>') |
        ForEach-Object { $_.Groups['skill'].Value } | Where-Object { $_ -in $folders -and $_ -ne $name } | Sort-Object -Unique
    foreach ($dependency in $used) {
        if ($dependency -notin $requires[$name]) {
            Add-Problem "skills/$name/SKILL.md" "passes <$dependency> but does not declare it in requires"
        }
    }
}

foreach ($name in $requires.Keys) {
    foreach ($dependency in $requires[$name]) {
        if ($requires.ContainsKey($dependency) -and $name -in $requires[$dependency]) {
            Add-Problem $name "depends on $dependency, which depends back on it"
        }
    }
}

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

if ($problems.Count -eq 0) {
    Write-Output "Registration check passed: $($folders.Count) skills, both tables and dependencies agree."
    exit 0
}
Write-Output "Registration check: $($problems.Count) problem(s)."
Write-Output ''
Write-Output '| Where | Problem |'
Write-Output '| --- | --- |'
foreach ($problem in $problems) {
    Write-Output "| ``$($problem.Where)`` | $($problem.What -replace '\|', '\|') |"
}
exit 1
