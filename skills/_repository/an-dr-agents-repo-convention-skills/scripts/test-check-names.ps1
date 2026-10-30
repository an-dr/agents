#Requires -Version 7
<# Breaks a copy of the skills one way at a time and expects check-names.ps1 to name each break. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).ProviderPath
$checker = Join-Path $PSScriptRoot 'check-names.ps1'
$fixtureRoot = Join-Path $repositoryRoot '.artifacts/test-check-names'

function Remove-Fixture {
    # Windows indexers and scanners can briefly hold a freshly copied file, so retry.
    for ($attempt = 1; $attempt -le 8; $attempt++) {
        try { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction Stop; return }
        catch { if ($attempt -eq 8) { throw }; Start-Sleep -Milliseconds 500 }
    }
}

function New-Fixture {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Fixture }
    New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
    Copy-Item -LiteralPath (Join-Path $repositoryRoot 'skills') -Destination $fixtureRoot -Recurse
}

function Rename-FixtureSkill([string]$Old, [string]$New) {
    $directory = Get-ChildItem -Path (Join-Path $fixtureRoot 'skills/*') -Directory | ForEach-Object { Join-Path $_.FullName $Old } | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    Rename-Item -LiteralPath $directory -NewName $New
}

function Assert-Check([string]$Case, [int]$ExpectedExit, [string]$ExpectedText) {
    $output = (& pwsh -NoProfile -File $checker -Root $fixtureRoot) -join "`n"
    if ($LASTEXITCODE -ne $ExpectedExit) { throw "$Case`: exit $LASTEXITCODE, expected $ExpectedExit.`n$output" }
    if ($ExpectedText -and -not $output.Contains($ExpectedText)) { throw "$Case`: output lacks '$ExpectedText'.`n$output" }
}

New-Fixture
Assert-Check 'clean copy' 0 'Name check passed'

New-Fixture
Rename-FixtureSkill 'an-dr-dev-implement-code' 'an-dr-dev-ship-code'
Assert-Check 'unlisted verb' 1 "verb 'ship' is not in the Verbs table"

New-Fixture
Rename-FixtureSkill 'an-dr-dev-implement-code' 'an-dr-dev-repair-code'
Assert-Check 'verb from PowerShell but not ours' 1 "verb 'repair' is not in the Verbs table"

New-Fixture
Rename-FixtureSkill 'an-dr-dev-implement-code' 'an-dr-build-build-code'
Assert-Check 'unknown group' 1 "group 'build' is not one of"

New-Fixture
Rename-FixtureSkill 'an-dr-dev-implement-code' 'an-dr-files'
Assert-Check 'group alone' 1 'needs a group and a verb'

New-Fixture
Rename-FixtureSkill 'an-dr-dev-implement-code' 'an-dr-dev-fix'
Assert-Check 'noun is optional' 0 'Name check passed'

New-Fixture
Rename-FixtureSkill 'an-dr-dev-implement-code' 'dev-build-code'
Assert-Check 'missing namespace' 1 "name must start with 'an-dr-'"

New-Fixture
Rename-FixtureSkill 'an-dr-concept-ai-slop' 'an-dr-ai-slop'
Assert-Check 'concept without its type' 1 'a concept must be named an-dr-concept-<name>'

New-Fixture
Rename-FixtureSkill 'an-dr-convention-markdown' 'an-dr-markdown'
Assert-Check 'convention without its type' 1 'a convention must be named an-dr-convention-<name>'

New-Fixture
Rename-FixtureSkill 'an-dr-agents-repo-convention-skills' 'an-dr-skills'
Assert-Check 'repository skill without its prefix' 1 'must be named an-dr-agents-<name>'

New-Fixture
Rename-FixtureSkill 'an-dr-agents-repo-convention-skills' 'an-dr-agents-repo-skills'
Assert-Check 'repository convention without its type word' 1 'must be named an-dr-agents-repo-convention-<name>'

New-Fixture
Rename-FixtureSkill 'an-dr-agents-repo-modify' 'an-dr-agents-repo-ship'
Assert-Check 'repository action with an unlisted verb' 1 "verb 'ship' is not in the Verbs table"

Remove-Fixture
Write-Output 'check-names tests passed (12 cases).'
