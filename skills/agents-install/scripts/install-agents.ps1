#Requires -Version 7
<#
  Installs this agents clone globally: a managed instruction block in each
  tool's user-level instruction file, plus one directory junction per skill in
  each tool's user-level skills directory. Idempotent and re-runnable.
#>
param(
    [string]$AgentsRoot,
    [string[]]$Tools,
    [switch]$SkipSkills,
    [switch]$Force,
    [switch]$Uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Install.Common.psm1') -Force

$root = Resolve-AgentsRoot -RequestedRoot $AgentsRoot
$targets = Get-AgentsToolTarget -Only $Tools
if (-not $targets) {
    throw 'No supported tool found. Pass -Tools to install for a tool whose home directory does not exist yet.'
}

$skills = Get-AgentsSkill -AgentsRoot $root
$conflicts = @()

Write-Output "Agents root: $root"
Write-Output "Tools: $(($targets.Name) -join ', ')"
Write-Output ''

foreach ($tool in $targets) {
    Write-Output "## $($tool.Name)"

    if ($Uninstall) {
        $state = Remove-AgentsManagedBlock -Path $tool.Instructions
        Write-Output "  instructions  $state  $($tool.Instructions)"
    }
    else {
        $block = Build-AgentsBlock -AgentsRoot $root -SupportsImport $tool.SupportsImport
        $state = Set-AgentsManagedBlock -Path $tool.Instructions -Block $block
        Write-Output "  instructions  $state  $($tool.Instructions)"
    }

    if ($SkipSkills) {
        Write-Output '  skills        skipped'
        Write-Output ''
        continue
    }
    if (-not $tool.SkillsDir) {
        Write-Output '  skills        unsupported  (no user-level skills directory for this tool)'
        Write-Output ''
        continue
    }

    $counts = @{}
    foreach ($skill in $skills) {
        $linkPath = Join-Path $tool.SkillsDir $skill.Name
        $state = if ($Uninstall) {
            Remove-DirectoryLink -Path $linkPath
        }
        else {
            Set-DirectoryLink -Path $linkPath -Target $skill.FullName -Force:$Force
        }

        if ($state -in @('conflict', 'not-a-link')) {
            $conflicts += "$($tool.Name): $linkPath exists as a real directory ($state)."
        }
        $counts[$state] = 1 + ($counts[$state] ?? 0)
    }
    if (-not $Uninstall) {
        $stale = @(Remove-StaleAgentsLink -SkillsDirectory $tool.SkillsDir -AgentsRoot $root -CurrentSkill $skills.Name)
        if ($stale.Count -gt 0) {
            $counts['stale-removed'] = $stale.Count
            Write-Output "  pruned        $($stale -join ', ')"
        }
    }
    $summary = ($counts.GetEnumerator() | Sort-Object Key | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' '
    Write-Output "  skills        $summary  ->  $($tool.SkillsDir)"
    Write-Output ''
}

if ($conflicts) {
    Write-Output '## Conflicts'
    $conflicts | ForEach-Object { Write-Output "  $_" }
    Write-Output ''
    Write-Output 'Resolve each conflict by hand, or re-run with -Force to replace the directory.'
    exit 2
}

$verb = if ($Uninstall) { 'Uninstall' } else { 'Install' }
Write-Output "$verb complete. Verify with:"
Write-Output "  pwsh $(Join-Path $PSScriptRoot 'verify-agents.ps1')"
