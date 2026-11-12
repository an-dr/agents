#Requires -Version 7
<# Vendored runner: each skill owns its copy. Never invokes behavior evaluations. #>
[CmdletBinding()]
param([string]$TestsPath = $PSScriptRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $TestsPath -PathType Container)) { throw "Tests folder not found: $TestsPath" }
# Top-level discovery keeps fixture scripts from becoming test entry points.
$tests = @(Get-ChildItem -LiteralPath $TestsPath -File -Filter 'test-*.ps1' | Sort-Object Name)
if ($tests.Count -eq 0) { throw "No script tests found in $TestsPath." }
$failed = 0
Write-Output '| Script test | Result |'
Write-Output '| --- | --- |'
foreach ($test in $tests) {
    $output = @(& pwsh -NoProfile -NonInteractive -File $test.FullName 2>&1)
    $code = $LASTEXITCODE
    if ($code -ne 0) { $failed++ }
    $status = if ($code -eq 0) { 'pass' } else { "FAIL (exit $code)" }
    Write-Output "| ``$($test.Name)`` | $status |"
    if ($code -ne 0) {
        Write-Output '```text'
        $output | ForEach-Object { Write-Output "$_" }
        Write-Output '```'
    }
}
Write-Output "$($tests.Count - $failed) of $($tests.Count) script test(s) passed. No agent evaluations ran."
if ($failed -gt 0) { exit 1 }
