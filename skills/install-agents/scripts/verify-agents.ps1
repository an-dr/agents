#Requires -Version 7
<#
  Verifies a global agents installation: clone health, the managed instruction
  block in each tool, and skill junctions that actually resolve to SKILL.md.
  Prints a Markdown result table and exits non-zero when any check fails.
#>
param(
    [string]$AgentsRoot,
    [string[]]$Tools
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Install.Common.psm1') -Force

$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    <# Records one check outcome for the summary table. #>
    param(
        [Parameter(Mandatory)][string]$Scope,
        [Parameter(Mandatory)][string]$Check,
        [Parameter(Mandatory)][ValidateSet('pass', 'fail', 'warn')][string]$Status,
        [string]$Detail = ''
    )
    $results.Add([pscustomobject]@{ Scope = $Scope; Check = $Check; Status = $Status; Detail = $Detail })
}

# --- Clone ---
$root = Resolve-AgentsRoot -RequestedRoot $AgentsRoot
Add-Result -Scope 'clone' -Check 'root' -Status 'pass' -Detail $root

$skills = Get-AgentsSkill -AgentsRoot $root
if ($skills.Count -gt 0) {
    Add-Result -Scope 'clone' -Check 'skills' -Status 'pass' -Detail "$($skills.Count) skills with SKILL.md"
}
else {
    Add-Result -Scope 'clone' -Check 'skills' -Status 'fail' -Detail 'no skill directory contains SKILL.md'
}

$describe = & git -C $root describe --always --dirty 2>$null
if ($LASTEXITCODE -eq 0 -and $describe) {
    $status = if ("$describe" -like '*-dirty') { 'warn' } else { 'pass' }
    Add-Result -Scope 'clone' -Check 'git' -Status $status -Detail "$describe"
}
else {
    Add-Result -Scope 'clone' -Check 'git' -Status 'warn' -Detail 'clone is not a git repository; it cannot be updated by pull'
}

# --- Tools ---
$targets = Get-AgentsToolTarget -Only $Tools
if (-not $targets) {
    Add-Result -Scope 'tools' -Check 'detected' -Status 'fail' -Detail 'no supported tool home directory found'
}

$markers = Get-AgentsBlockMarker
$expectedPolicy = ($root -replace '\\', '/') + '/AGENTS.md'

foreach ($tool in $targets) {
    $scope = $tool.Id

    if (-not (Test-Path -LiteralPath $tool.Instructions)) {
        Add-Result -Scope $scope -Check 'instructions' -Status 'fail' -Detail "missing $($tool.Instructions)"
    }
    else {
        $content = Get-Content -LiteralPath $tool.Instructions -Raw
        if ($content -notlike "*$($markers.Begin)*" -or $content -notlike "*$($markers.End)*") {
            Add-Result -Scope $scope -Check 'instructions' -Status 'fail' -Detail 'managed block missing or truncated'
        }
        elseif ($content -notlike "*$expectedPolicy*") {
            Add-Result -Scope $scope -Check 'instructions' -Status 'fail' -Detail "block does not point at $expectedPolicy"
        }
        elseif ($tool.SupportsImport -and $content -notlike "*@$expectedPolicy*") {
            Add-Result -Scope $scope -Check 'instructions' -Status 'fail' -Detail 'policy path is present but not written as an @ import'
        }
        else {
            Add-Result -Scope $scope -Check 'instructions' -Status 'pass' -Detail $tool.Instructions
        }
    }

    if (-not $tool.SkillsDir) {
        Add-Result -Scope $scope -Check 'skills' -Status 'warn' -Detail 'no user-level skills directory for this tool'
        continue
    }

    $broken = @()
    $linked = 0
    foreach ($skill in $skills) {
        $linkPath = Join-Path $tool.SkillsDir $skill.Name
        $linkTarget = Get-DirectoryLinkTarget -Path $linkPath

        if (-not (Test-Path -LiteralPath $linkPath)) { $broken += "$($skill.Name): missing"; continue }
        if (-not $linkTarget) { $broken += "$($skill.Name): real directory, not a link"; continue }
        if (-not (Test-SamePath -Left $linkTarget -Right $skill.FullName)) {
            $broken += "$($skill.Name): points at $linkTarget"
            continue
        }
        # Reading through the link proves the junction actually traverses.
        if (-not (Test-Path -LiteralPath (Join-Path $linkPath 'SKILL.md'))) {
            $broken += "$($skill.Name): SKILL.md unreadable through the link"
            continue
        }
        $linked++
    }

    if ($broken.Count -eq $skills.Count) {
        Add-Result -Scope $scope -Check 'skills' -Status 'fail' -Detail "0/$($skills.Count) linked in $($tool.SkillsDir); not installed"
    }
    elseif ($broken) {
        # Keep the row readable; the pattern matters more than the full list.
        $shown = ($broken | Select-Object -First 3) -join '; '
        $rest = if ($broken.Count -gt 3) { " (+$($broken.Count - 3) more)" } else { '' }
        Add-Result -Scope $scope -Check 'skills' -Status 'fail' -Detail "$linked/$($skills.Count) linked; $shown$rest"
    }
    else {
        Add-Result -Scope $scope -Check 'skills' -Status 'pass' -Detail "$linked/$($skills.Count) linked in $($tool.SkillsDir)"
    }
}

# --- Report ---
Write-Output '| Scope | Check | Status | Detail |'
Write-Output '| --- | --- | --- | --- |'
foreach ($r in $results) {
    Write-Output "| $($r.Scope) | $($r.Check) | $($r.Status) | $($r.Detail) |"
}
Write-Output ''

$failed = @($results | Where-Object Status -eq 'fail')
$warned = @($results | Where-Object Status -eq 'warn')
if ($failed) {
    Write-Output "$($failed.Count) check(s) failed, $($warned.Count) warning(s)."
    exit 1
}
Write-Output "All checks passed, $($warned.Count) warning(s)."
