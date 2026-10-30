#Requires -Version 7
<#
    Checks every SKILL.md against convention-agent-skill: the description ends in a
    trigger sentence, one title that matches the skill's kind, the section order for
    that kind, and the size limit.
    Prints a Markdown table of problems and exits 1 when there are any.
#>
[CmdletBinding()]
param([string]$Root = (Join-Path $PSScriptRoot '../../..'))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path -LiteralPath $Root).ProviderPath
$skillsDir = Join-Path $Root 'skills'
$maxLines = 150
$problems = [System.Collections.Generic.List[object]]::new()
function Add-Problem([string]$Where, [string]$What) {
    $problems.Add([pscustomobject]@{ Where = $Where; What = $What })
}

$checked = 0
foreach ($directory in Get-ChildItem -LiteralPath $skillsDir -Directory | Sort-Object Name) {
    $name = $directory.Name
    $file = Join-Path $directory.FullName 'SKILL.md'
    if (-not (Test-Path -LiteralPath $file)) { continue }
    $checked++
    $where = "skills/$name/SKILL.md"
    $lines = [IO.File]::ReadAllLines($file)
    $kind = if ($name -like 'concept-*') { 'concept' } elseif ($name -like 'convention-*') { 'convention' } else { 'task' }

    # Frontmatter: the description and where the body starts.
    $description = $null
    $bodyStart = 0
    if ($lines.Count -gt 0 -and $lines[0] -eq '---') {
        for ($i = 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -eq '---') { $bodyStart = $i + 1; break }
            if ($lines[$i] -match '^description:\s*(?<v>.+)$') { $description = $Matches['v'] }
        }
    }
    if (-not $description) { Add-Problem $where 'has no one-line description'; }
    else {
        if ($description -cnotmatch '^[A-Z]') { Add-Problem $where 'description does not start with a capital letter' }
        if ($description -cnotmatch '(^|[.;] )Use [a-z]') { Add-Problem $where "description has no trigger sentence beginning 'Use '" }
    }
    if ($lines.Count -gt $maxLines) { Add-Problem $where "has $($lines.Count) lines; split it or move logic into a script (limit $maxLines)" }

    # Headings outside code fences.
    $titles = [System.Collections.Generic.List[string]]::new()
    $sections = [System.Collections.Generic.List[string]]::new()
    $inFence = $false
    for ($i = $bodyStart; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^```') { $inFence = -not $inFence; continue }
        if ($inFence) { continue }
        if ($lines[$i] -match '^# (?<t>.+)$') { $titles.Add($Matches['t']) }
        elseif ($lines[$i] -match '^## (?<t>.+)$') { $sections.Add($Matches['t']) }
    }

    if ($titles.Count -ne 1) { Add-Problem $where "has $($titles.Count) top-level titles; it needs exactly one" }
    elseif ($kind -eq 'concept' -and $titles[0] -cnotmatch '^Concept: ') { Add-Problem $where "title '$($titles[0])' must start with 'Concept: '" }
    elseif ($kind -eq 'convention' -and $titles[0] -cnotmatch '^Convention: ') { Add-Problem $where "title '$($titles[0])' must start with 'Convention: '" }
    elseif ($kind -eq 'task' -and $titles[0] -cmatch '^(Concept|Convention): ') { Add-Problem $where "title '$($titles[0])' uses a concept or convention prefix on a task skill" }

    $last = if ($sections.Count -gt 0) { $sections[$sections.Count - 1] } else { $null }
    switch ($kind) {
        'task' {
            if ($sections -contains 'Rules' -and $last -cne 'Rules') { Add-Problem $where "'## Rules' must be the last section, not '## $last'" }
            if ($sections -contains 'Output' -and $sections -contains 'Rules' -and $sections.IndexOf('Output') -gt $sections.IndexOf('Rules')) {
                Add-Problem $where "'## Output' must come before '## Rules'"
            }
        }
        'concept' {
            if ($sections -notcontains 'Violations') { Add-Problem $where "has no '## Violations' section" }
        }
        'convention' {
            if ($sections -contains 'Examples' -and $last -cne 'Examples') { Add-Problem $where "'## Examples' must be the last section, not '## $last'" }
            if ($sections -contains 'Check' -and $sections -contains 'Examples' -and $sections.IndexOf('Check') -gt $sections.IndexOf('Examples')) {
                Add-Problem $where "'## Check' must come before '## Examples'"
            }
        }
    }
}

if ($problems.Count -eq 0) {
    Write-Output "Skill check passed: $checked skills follow convention-agent-skill."
    exit 0
}
Write-Output "Skill check: $($problems.Count) problem(s)."
Write-Output ''
Write-Output '| Where | Problem |'
Write-Output '| --- | --- |'
foreach ($problem in $problems) {
    Write-Output "| ``$($problem.Where)`` | $($problem.What -replace '\|', '\|') |"
}
exit 1
