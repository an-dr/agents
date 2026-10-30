#Requires -Version 7
<#
    Runs every check this repository has: each skill's test-*.ps1, the
    registration check, the script and skill-text checks, the reference check,
    and the Markdown format check.
    Prints one Markdown table and exits 1 when any step fails.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
$skills = Join-Path $root 'skills'

$steps = [System.Collections.Generic.List[object]]::new()
foreach ($test in Get-ChildItem -LiteralPath $skills -Recurse -File -Filter 'test-*.ps1' | Sort-Object FullName) {
    $steps.Add(@{ Name = ($test.FullName.Substring($root.Length + 1) -replace '\\', '/'); Script = $test.FullName; Arguments = @() })
}
$steps.Add(@{ Name = 'registration'; Script = Join-Path $skills 'convention-agent-skill/scripts/check-registration.ps1'; Arguments = @('-Root', $root) })
$steps.Add(@{ Name = 'scripts'; Script = Join-Path $skills 'convention-script/scripts/check-scripts.ps1'; Arguments = @('-Root', $root) })
$steps.Add(@{ Name = 'skills'; Script = Join-Path $skills 'convention-agent-skill/scripts/check-skills.ps1'; Arguments = @('-Root', $root) })
$steps.Add(@{ Name = 'references'; Script = Join-Path $skills 'ai-prompt-review/scripts/check-references.ps1'; Arguments = @('-Path', $root) })
# The repository's own Markdown only; ignored local artifacts are not checked.
foreach ($target in @('AGENTS.md', 'README.md', 'skills')) {
    $steps.Add(@{ Name = "markdown $target"; Script = Join-Path $skills 'convention-markdown/scripts/check-markdown.ps1'; Arguments = @((Join-Path $root $target)) })
}

$results = [System.Collections.Generic.List[object]]::new()
foreach ($step in $steps) {
    $arguments = $step.Arguments
    $output = @(& pwsh -NoProfile -File $step.Script @arguments 2>&1)
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
