#Requires -Version 7
<#
    Reports how a change moves what agents load: the approximate tokens of every
    changed AGENTS.md, SKILL.md, and skill reference file, and of the always-loaded
    set (AGENTS.md plus every skill's description), before and after. Tokens are
    estimated as characters / 4. Compares -Base with the working tree.
#>
[CmdletBinding()]
param(
    [string]$Root = (Join-Path $PSScriptRoot '../../../..'),
    [string]$Base = 'HEAD'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path -LiteralPath $Root).ProviderPath
# git show output is decoded with the console encoding; without UTF-8 every dash counts as several characters.
[Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
$loaded = '^(AGENTS\.md|skills/[^/]+/[^/]+/(SKILL\.md|references/.+\.md))$'

function Get-Tokens([string]$Text) { if ($null -eq $Text) { 0 } else { [int][Math]::Round($Text.Length / 4) } }
function Get-Old([string]$Path) {
    $text = (& git -C $Root show "${Base}:$Path" 2>$null) -join "`n"
    if ($LASTEXITCODE -ne 0) { return $null }
    return $text
}
function Get-New([string]$Path) {
    $full = Join-Path $Root $Path
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { return $null }
    return ([IO.File]::ReadAllLines($full) -join "`n")
}
function Get-Description([string]$Text) {
    if ($null -eq $Text) { return '' }
    $match = [regex]::Match($Text, '(?m)^description:\s*(.*)$')
    if ($match.Success) { return $match.Groups[1].Value } else { return '' }
}

$null = & git -C $Root rev-parse --verify --quiet $Base
if ($LASTEXITCODE -ne 0) { throw "Unknown -Base '$Base'." }

$changed = [Collections.Generic.HashSet[string]]::new()
@(& git -C $Root diff --name-only $Base) + @(& git -C $Root ls-files --others --exclude-standard) |
    Where-Object { $_ -match $loaded } | ForEach-Object { $null = $changed.Add($_) }

$rows = foreach ($path in ($changed | Sort-Object)) {
    $before = Get-Tokens (Get-Old $path)
    $after = Get-Tokens (Get-New $path)
    [pscustomobject]@{ Path = $path; Before = $before; After = $after; Change = $after - $before }
}

# The always-loaded set: AGENTS.md and the description of every skill, before and after.
$oldSkills = @(& git -C $Root ls-tree -r --name-only $Base -- skills | Where-Object { $_ -match '^skills/[^/]+/[^/]+/SKILL\.md$' })
$newSkills = @(Get-ChildItem -Path (Join-Path $Root 'skills/*/*/SKILL.md') -File | ForEach-Object { ($_.FullName.Substring($Root.Length + 1)) -replace '\\', '/' })
$alwaysBefore = (Get-Tokens (Get-Old 'AGENTS.md')) + (($oldSkills | ForEach-Object { Get-Tokens (Get-Description (Get-Old $_)) }) | Measure-Object -Sum).Sum
$alwaysAfter = (Get-Tokens (Get-New 'AGENTS.md')) + (($newSkills | ForEach-Object { Get-Tokens (Get-Description (Get-New $_)) }) | Measure-Object -Sum).Sum

Write-Output "| File | Before | After | Change |"
Write-Output "| --- | ---: | ---: | ---: |"
foreach ($row in $rows) { Write-Output ("| ``{0}`` | {1} | {2} | {3:+#;-#;0} |" -f $row.Path, $row.Before, $row.After, $row.Change) }
$sumBefore = ($rows | Measure-Object -Property Before -Sum).Sum
$sumAfter = ($rows | Measure-Object -Property After -Sum).Sum
Write-Output ("| changed files | {0} | {1} | {2:+#;-#;0} |" -f [int]$sumBefore, [int]$sumAfter, [int]($sumAfter - $sumBefore))
Write-Output ("| always loaded | {0} | {1} | {2:+#;-#;0} |" -f [int]$alwaysBefore, [int]$alwaysAfter, [int]($alwaysAfter - $alwaysBefore))
Write-Output ''
Write-Output 'Approximate tokens (characters / 4). Always loaded: AGENTS.md and every skill description.'
