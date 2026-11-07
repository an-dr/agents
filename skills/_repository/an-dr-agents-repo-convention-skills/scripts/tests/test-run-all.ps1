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
    Set-Content -LiteralPath (Join-Path $first 'scripts/tests/run.ps1') -Value "#Requires -Version 7`nWrite-Output 'first ran'"
    Remove-Item -LiteralPath (Join-Path $first 'scripts/tests/fixtures') -Recurse -Force
    Remove-Item -LiteralPath (Join-Path $first 'scripts/tests/test-trap.ps1') -Force

    # In a Git tree the default runs only affected suites: the changed skill, its dependents, and repository checks.
    $dependent = Add-Suite 'actions' 'example-dependent' "Write-Output 'dependent ran'"
    Set-Content -LiteralPath (Join-Path $dependent 'SKILL.md') -Value "---`nname: example-dependent`nmetadata:`n  an-dr.dependencies: example-one`n---`n# example-dependent"
    $checks = Add-Suite 'conventions' 'example-checks' "Write-Output 'repository checks ran'"
    Set-Content -LiteralPath (Join-Path $checks 'scripts/tests/test-repository.ps1') -Value "Write-Output 'inert'"
    & git -C $scratch init --quiet
    & git -C $scratch -c core.autocrlf=false add -A
    & git -C $scratch -c user.name=test -c user.email=test@example.invalid commit --quiet -m 'baseline'
    Assert-Run 0 @('Nothing changed, so no suite is affected')
    Add-Content -LiteralPath (Join-Path $first 'SKILL.md') -Value 'changed'
    $output = @(& pwsh -NoProfile -NonInteractive -File (Join-Path $scratch 'tests/run-all.ps1') 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Affected run failed.`n$output" }
    foreach ($expected in 'Affected suites: 3 of 4', 'example-one/', 'example-dependent/', 'example-checks/') {
        if (-not $output.Contains($expected)) { throw "Missing '$expected'.`n$output" }
    }
    if ($output.Contains('example-two/')) { throw "An unaffected suite ran.`n$output" }
    $output = @(& pwsh -NoProfile -NonInteractive -File (Join-Path $scratch 'tests/run-all.ps1') -All 2>&1) -join "`n"
    if (-not $output.Contains('4 of 4 step(s) passed')) { throw "-All did not run every suite.`n$output" }
} finally {
    $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolvedScratch = [IO.Path]::GetFullPath($scratch)
    if (-not $resolvedScratch.StartsWith($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or -not (Split-Path -Leaf $resolvedScratch).StartsWith('agents-test-discovery-')) { throw 'Unsafe discovery fixture cleanup.' }
    Remove-Item -LiteralPath $resolvedScratch -Recurse -Force
}
Write-Output 'Root test discovery passed (9 scenarios). No agent evaluations ran.'
