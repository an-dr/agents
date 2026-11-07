#Requires -Version 7
<#
    Discover conventional skill test runners; each suite owns its checks and fixtures.
    By default only the suites a change affects run: every skill with a changed
    file, every skill declaring a dependency on one, and the suites that own
    repository-wide checks. -All runs every suite, as CI does.
#>
[CmdletBinding()]
param(
    # Run every suite instead of the affected ones.
    [switch]$All,
    # Also count files changed between this ref and HEAD, such as the branch base.
    [string]$Base
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$skills = Join-Path $root 'skills'

function Get-ChangedPath {
    <# Paths changed in the working tree, untracked ones included, plus those since -Base; $null outside Git. #>
    $null = & git -C $root rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    $paths = [Collections.Generic.HashSet[string]]::new()
    foreach ($line in @(& git -C $root status --porcelain=v1 --untracked-files=all 2>$null)) {
        # 'XY path' or 'XY old -> new' for a rename.
        $path = $line.Substring(3) -replace '^.* -> ', ''
        $null = $paths.Add($path.Trim('"'))
    }
    if ($Base) {
        $diff = @(& git -C $root diff --name-only "$Base...HEAD" 2>$null)
        if ($LASTEXITCODE -ne 0) { throw "Cannot compare with -Base '$Base'." }
        $diff | ForEach-Object { $null = $paths.Add($_) }
    }
    return , @($paths)
}

# Discover skills by their conventional manifest, then only their local runner.
# Searching recursively for arbitrary scripts would execute fixture programs as tests.
$suites = [Collections.Generic.List[object]]::new()
foreach ($manifest in Get-ChildItem -Path (Join-Path $skills '*/*/SKILL.md') -File | Sort-Object FullName) {
    $directory = $manifest.DirectoryName
    $runner = Join-Path $directory 'scripts/tests/run.ps1'
    $dependencies = @()
    $frontmatter = Get-Content -LiteralPath $manifest.FullName -TotalCount 20
    $declared = $frontmatter | Where-Object { $_ -match '^\s*an-dr\.dependencies:\s*(.*)$' } | Select-Object -First 1
    if ($declared -and $declared -match '^\s*an-dr\.dependencies:\s*(.*)$') { $dependencies = @($Matches[1] -split '\s+' | Where-Object { $_ }) }
    $suites.Add([pscustomobject]@{
            Skill        = Split-Path -Leaf $directory
            Folder       = ($directory.Substring($root.Length + 1) -replace '\\', '/') + '/'
            Name         = ($runner.Substring($root.Length + 1) -replace '\\', '/')
            Script       = $runner
            HasTests     = (Test-Path -LiteralPath $runner -PathType Leaf) -or (Test-Path -LiteralPath (Join-Path $directory 'scripts') -PathType Container)
            # A test-repository*.ps1 checks the whole repository, so any change can break it.
            Repository   = @(Get-ChildItem -Path (Join-Path $directory 'scripts/tests') -Filter 'test-repository*.ps1' -File -ErrorAction SilentlyContinue).Count -gt 0
            Dependencies = $dependencies
        })
}
$steps = @($suites | Where-Object HasTests)
if ($steps.Count -eq 0) { throw "No conventional skill test runners found under '$skills'." }

if (-not $All) {
    $changed = Get-ChangedPath
    if ($null -eq $changed) {
        Write-Output 'Not a Git working tree, so changes are unknown: running every suite.'
    }
    elseif ($changed.Count -eq 0) {
        Write-Output 'Nothing changed, so no suite is affected. Run with -All for every suite.'
        exit 0
    }
    else {
        $changedSkills = @($suites | Where-Object { $folder = $_.Folder; @($changed | Where-Object { $_.StartsWith($folder) }).Count -gt 0 } | ForEach-Object Skill)
        $selected = @($steps | Where-Object {
                $_.Repository -or
                $changedSkills -contains $_.Skill -or
                @($_.Dependencies | Where-Object { $changedSkills -contains $_ }).Count -gt 0
            })
        Write-Output "Affected suites: $($selected.Count) of $($steps.Count) ($($changed.Count) changed file(s)). Run with -All for every suite."
        Write-Output ''
        $steps = $selected
    }
}

$results = [System.Collections.Generic.List[object]]::new()
foreach ($step in $steps) {
    if (-not (Test-Path -LiteralPath $step.Script -PathType Leaf)) {
        $results.Add([pscustomobject]@{ Name = $step.Name; Exit = 1; Output = @("Missing conventional runner: $($step.Script)") })
        continue
    }
    $output = @(& pwsh -NoProfile -NonInteractive -File $step.Script 2>&1)
    $results.Add([pscustomobject]@{ Name = $step.Name; Exit = $LASTEXITCODE; Output = $output })
}

$failed = @($results | Where-Object Exit -ne 0)
foreach ($result in $failed) {
    Write-Output "### $($result.Name) failed (exit $($result.Exit))"
    Write-Output ''
    Write-Output '```text'
    $result.Output | ForEach-Object { Write-Output "$_" }
    Write-Output '```'
    Write-Output ''
}

Write-Output '| Step | Result |'
Write-Output '| --- | --- |'
foreach ($result in $results) {
    $status = if ($result.Exit -eq 0) { 'pass' } else { "FAIL (exit $($result.Exit))" }
    Write-Output "| ``$($result.Name)`` | $status |"
}
Write-Output ''
Write-Output "$($results.Count - $failed.Count) of $($results.Count) step(s) passed."
if ($failed.Count -gt 0) { exit 1 }
