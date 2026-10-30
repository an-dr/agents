#Requires -Version 7
<# Discover conventional skill test runners; each suite owns its checks and fixtures. #>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$skills = Join-Path $root 'skills'

$steps = [System.Collections.Generic.List[object]]::new()
# Discover skills by their conventional manifest, then only their local runner.
# Searching recursively for arbitrary scripts would execute fixture programs as tests.
foreach ($manifest in Get-ChildItem -Path (Join-Path $skills '*/*/SKILL.md') -File | Sort-Object FullName) {
    $runner = Join-Path $manifest.DirectoryName 'scripts/tests/run.ps1'
    if ((Test-Path -LiteralPath $runner -PathType Leaf) -or (Test-Path -LiteralPath (Join-Path $manifest.DirectoryName 'scripts') -PathType Container)) {
        $steps.Add(@{ Name = ($runner.Substring($root.Length + 1) -replace '\\', '/'); Script = $runner; Arguments = @() })
    }
}
if ($steps.Count -eq 0) { throw "No conventional skill test runners found under '$skills'." }

$results = [System.Collections.Generic.List[object]]::new()
foreach ($step in $steps) {
    if (-not (Test-Path -LiteralPath $step.Script -PathType Leaf)) {
        $results.Add([pscustomobject]@{ Name = $step.Name; Exit = 1; Output = @("Missing conventional runner: $($step.Script)") })
        continue
    }
    $arguments = $step.Arguments
    $output = @(& pwsh -NoProfile -NonInteractive -File $step.Script @arguments 2>&1)
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
