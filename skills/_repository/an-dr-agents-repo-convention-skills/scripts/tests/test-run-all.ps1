#Requires -Version 7
<# Exercise discovery using a copy of the real repository entry point and inert fake suites. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
$source = Join-Path $repositoryRoot 'tests/run-all.ps1'
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('agents-test-discovery-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path (Join-Path $scratch 'tests')
Copy-Item -LiteralPath $source -Destination (Join-Path $scratch 'tests/run-all.ps1')
function Add-Suite([string]$Category, [string]$Name, [string]$Body) {
    $skill = Join-Path $scratch "skills/$Category/$Name"
    $null = New-Item -ItemType Directory -Path (Join-Path $skill 'scripts/tests') -Force
    Set-Content -LiteralPath (Join-Path $skill 'SKILL.md') -Value "# $Name"
    Set-Content -LiteralPath (Join-Path $skill 'scripts/tests/run.ps1') -Value "#Requires -Version 7`n$Body"
    return $skill
}
function Assert-Run([int]$Exit, [string[]]$Messages) {
    $output = @(& pwsh -NoProfile -NonInteractive -File (Join-Path $scratch 'tests/run-all.ps1') 2>&1) -join "`n"
    if ($LASTEXITCODE -ne $Exit) { throw "Expected exit $Exit, got $LASTEXITCODE.`n$output" }
    foreach ($message in $Messages) { if (-not $output.Contains($message)) { throw "Missing '$message'.`n$output" } }
}
try {
    $null = New-Item -ItemType Directory -Path (Join-Path $scratch 'skills')
    Assert-Run 1 @('No conventional skill test runners')
    $first = Add-Suite 'actions' 'example-one' "Write-Output 'first ran'"
    Assert-Run 0 @('example-one/scripts/tests/run.ps1', '1 of 1 step(s) passed')
    # A new conventional runner must be picked up without editing run-all.
    $second = Add-Suite '_custom' 'example-two' "Write-Output 'second ran'"
    Assert-Run 0 @('example-one/scripts/tests/run.ps1', 'example-two/scripts/tests/run.ps1', '2 of 2 step(s) passed')
    # Neither a nested fixture manifest nor an unregistered loose script is a suite.
    $fixture = Join-Path $first 'scripts/tests/fixtures/fake/scripts/tests'
    $null = New-Item -ItemType Directory -Path $fixture -Force
    Set-Content -LiteralPath (Join-Path $first 'scripts/tests/fixtures/fake/SKILL.md') -Value '# Fixture'
    Set-Content -LiteralPath (Join-Path $fixture 'run.ps1') -Value "throw 'nested fixture executed'"
    Set-Content -LiteralPath (Join-Path $first 'scripts/tests/test-trap.ps1') -Value "throw 'loose test executed'"
    Assert-Run 0 @('2 of 2 step(s) passed')
    Rename-Item -LiteralPath (Join-Path $first 'scripts/tests/run.ps1') -NewName 'disabled.ps1'
    Assert-Run 1 @('Missing conventional runner', 'example-two/scripts/tests/run.ps1', '1 of 2 step(s) passed')
    Rename-Item -LiteralPath (Join-Path $first 'scripts/tests/disabled.ps1') -NewName 'run.ps1'
    Set-Content -LiteralPath (Join-Path $first 'scripts/tests/run.ps1') -Value "Write-Output 'expected discovery failure'; exit 7"
    Assert-Run 1 @('expected discovery failure', 'FAIL (exit 7)', 'example-two/scripts/tests/run.ps1', '1 of 2 step(s) passed')
} finally {
    $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolvedScratch = [IO.Path]::GetFullPath($scratch)
    if (-not $resolvedScratch.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or -not (Split-Path -Leaf $resolvedScratch).StartsWith('agents-test-discovery-')) { throw 'Unsafe discovery fixture cleanup.' }
    Remove-Item -LiteralPath $resolvedScratch -Recurse -Force
}
Write-Output 'Root test discovery passed (6 scenarios). No agent evaluations ran.'
