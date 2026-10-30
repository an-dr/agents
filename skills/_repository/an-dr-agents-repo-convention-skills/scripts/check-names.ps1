#Requires -Version 7
<#
    Checks the names of this repository's skills. Every name starts with an-dr-, the
    namespace that keeps them apart from other skills installed beside them. After it:
    an action is <group>-<verb>, with an optional -<noun>, with a known group and a verb from the
    Verbs table of SKILL.md, a concept is concept-<name>, a convention is convention-<name>,
    and a skill of the repository itself, in an underscore folder, starts with agents-:
    agents-repo-<verb>[-<noun>] or agents-<verb>[-<noun>] for an action, and
    agents-repo-concept-<name> or agents-repo-convention-<name> for the other types.
    Prints a Markdown table of problems and exits 1 when there are any.
#>
[CmdletBinding()]
param([string]$Root = (Join-Path $PSScriptRoot '../../../..'))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path -LiteralPath $Root).ProviderPath
$skillsDir = Join-Path $Root 'skills'
$namespace = 'an-dr-'
$groups = @('ai-skill', 'ai', 'dev', 'architecture', 'project', 'text', 'git', 'files', 'env')
$skillFile = Join-Path $PSScriptRoot '../SKILL.md'
$verbs = @()
$inVerbs = $false
foreach ($line in [IO.File]::ReadAllLines($skillFile)) {
    if ($line -match '^## ') { $inVerbs = $line -ceq '## Verbs'; continue }
    if ($inVerbs -and $line -match '^\| `(?<verb>[a-z]+)` \|') { $verbs += $Matches['verb'] }
}
if ($verbs.Count -eq 0) { throw "No verbs found in the Verbs table of $skillFile." }
$problems = [System.Collections.Generic.List[object]]::new()
function Add-Problem([string]$Where, [string]$What) {
    $problems.Add([pscustomobject]@{ Where = $Where; What = $What })
}

$checked = 0
foreach ($file in Get-ChildItem -Path (Join-Path $skillsDir '*/*/SKILL.md') | Sort-Object FullName) {
    $checked++
    $name = $file.Directory.Name
    $category = $file.Directory.Parent.Name
    $where = "skills/$category/$name"
    $typeLine = [IO.File]::ReadAllLines($file.FullName) | Where-Object { $_ -match '^\s+an-dr\.type:\s*\S+\s*$' } | Select-Object -First 1
    $type = if ($typeLine) { ($typeLine -split ':\s*', 2)[1].Trim() } else { '' }

    if (-not $name.StartsWith($namespace)) { Add-Problem $where "name must start with '$namespace'"; continue }
    $rest = $name.Substring($namespace.Length)
    $parts = $rest -split '-'

    if ($category.StartsWith('_')) {
        if ($rest -cnotlike 'agents-*') { Add-Problem $where "a skill of the repository itself must be named ${namespace}agents-<name>"; continue }
        switch ($type) {
            'concept' { if ($rest -cnotlike 'agents-repo-concept-?*') { Add-Problem $where "a concept of the repository itself must be named ${namespace}agents-repo-concept-<name>" } }
            'convention' { if ($rest -cnotlike 'agents-repo-convention-?*') { Add-Problem $where "a convention of the repository itself must be named ${namespace}agents-repo-convention-<name>" } }
            'action' {
                $tail = (($rest -creplace '^agents-(repo-)?', '') -split '-')
                if ($tail[0] -cnotin $verbs) { Add-Problem $where "verb '$($tail[0])' is not in the Verbs table" }
            }
        }
        continue
    }

    switch ($type) {
        'concept' { if ($rest -cnotlike 'concept-?*') { Add-Problem $where "a concept must be named ${namespace}concept-<name>" } }
        'convention' { if ($rest -cnotlike 'convention-?*') { Add-Problem $where "a convention must be named ${namespace}convention-<name>" } }
        'action' {
            if ($parts.Count -lt 2) { Add-Problem $where 'an action needs a group and a verb: <group>-<verb>[-<noun>]'; break }
            $group = $groups | Where-Object { $rest -ceq $_ -or $rest.StartsWith("$_-", [StringComparison]::Ordinal) } | Sort-Object Length -Descending | Select-Object -First 1
            if (-not $group) { Add-Problem $where "group '$($parts[0])' is not one of $($groups -join ', ')"; break }
            $tail = $rest.Substring($group.Length).TrimStart('-')
            if (-not $tail) { Add-Problem $where 'an action needs a group and a verb: <group>-<verb>[-<noun>]'; break }
            $verb = ($tail -split '-')[0]
            if ($verb -cnotin $verbs) { Add-Problem $where "verb '$verb' is not in the Verbs table" }
        }
    }
}

if ($problems.Count -eq 0) {
    Write-Output "Name check passed: $checked skills follow the naming rule."
    exit 0
}
Write-Output "Name check: $($problems.Count) problem(s)."
Write-Output ''
Write-Output '| Where | Problem |'
Write-Output '| --- | --- |'
foreach ($problem in $problems) {
    Write-Output "| ``$($problem.Where)`` | $($problem.What -replace '\|', '\|') |"
}
exit 1
