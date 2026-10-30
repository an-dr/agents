#Requires -Version 7
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'run.ps1'
function Assert-Run([string]$Fixture, [int]$Exit, [string]$Expected) {
    $path = Join-Path $PSScriptRoot "fixtures/$Fixture"
    $output = (& pwsh -NoProfile -NonInteractive -File $runner -TestsPath $path 2>&1) -join "`n"
    if ($LASTEXITCODE -ne $Exit -or -not $output.Contains($Expected)) { throw "$Fixture`: expected $Exit and '$Expected'.`n$output" }
}
Assert-Run 'runner-pass' 0 '1 of 1 script test(s) passed'
Assert-Run 'runner-fail' 1 'expected fixture failure'
Assert-Run 'runner-exit' 1 'FAIL (exit 7)'
Assert-Run 'runner-mixed' 1 '| `test-z-ok.ps1` | pass |'
# The fixtures directory has no top-level tests; its nested scripts must not execute.
Assert-Run '' 1 'No script tests found'
Assert-Run 'missing' 1 'Tests folder not found'
Write-Output 'local runner tests passed (6 cases).'
