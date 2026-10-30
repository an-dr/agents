#Requires -Version 7
<# Breaks a copy of the repository one way at a time and expects check-registration.ps1 to name each break. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).ProviderPath
$checker = Join-Path $PSScriptRoot '../scripts/check-registration.ps1'
$fixtureRoot = Join-Path $repositoryRoot '.artifacts/test-check-registration'

function Remove-Fixture {
    $allowedRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot '.artifacts')) + [IO.Path]::DirectorySeparatorChar
    if (-not ([IO.Path]::GetFullPath($fixtureRoot)).StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Fixture removal escaped the artifact root: $fixtureRoot"
    }
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

function Edit-Fixture([string]$Path, [string]$Old, [string]$New) {
    $file = Join-Path $fixtureRoot $Path
    $text = [IO.File]::ReadAllText($file)
    if (-not $text.Contains($Old)) { throw "Fixture text '$Old' not found in $Path." }
    [IO.File]::WriteAllText($file, $text.Replace($Old, $New))
}

function Add-FixtureText([string]$Path, [string]$Text) {
    [IO.File]::AppendAllText((Join-Path $fixtureRoot $Path), "`n$Text`n")
}

function Assert-Check([string]$Case, [int]$ExpectedExit, [string]$ExpectedText, [string[]]$CheckerArgument = @()) {
    $output = (& pwsh -NoProfile -File $checker -Root $fixtureRoot @CheckerArgument) -join "`n"
    if ($LASTEXITCODE -ne $ExpectedExit) { throw "$Case`: exit $LASTEXITCODE, expected $ExpectedExit.`n$output" }
    if ($ExpectedText -and -not $output.Contains($ExpectedText)) { throw "$Case`: output lacks '$ExpectedText'.`n$output" }
}

New-Fixture
Assert-Check 'clean copy' 0 'Registration check passed'

New-Fixture
# Built at run time so the reference checker does not read it as a real skill name.
$extra = 'dev-' + 'unregistered'
New-Item -ItemType Directory -Path (Join-Path $fixtureRoot "skills/actions/$extra") | Out-Null
Set-Content -LiteralPath (Join-Path $fixtureRoot "skills/actions/$extra/SKILL.md") -Value "---`nname: $extra`n---"
Assert-Check 'unregistered folder' 1 'missing from the skills/README.md table'

New-Fixture
New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'skills/loose') | Out-Null
Assert-Check 'unknown category' 1 'is not a category folder'

New-Fixture
Move-Item -LiteralPath (Join-Path $fixtureRoot 'skills/actions/an-dr-dev-debug') -Destination (Join-Path $fixtureRoot 'skills/concepts/an-dr-dev-debug')
Assert-Check 'folder and type disagree' 1 'is a action but sits in concepts'

New-Fixture
Edit-Fixture 'skills/actions/an-dr-dev-debug/SKILL.md' 'an-dr.type: action' 'an-dr.type: tool'
Assert-Check 'invalid type' 1 "an-dr.type is 'tool'"

New-Fixture
Move-Item -LiteralPath (Join-Path $fixtureRoot 'skills/concepts/an-dr-concept-ai-slop') -Destination (Join-Path $fixtureRoot 'skills/concepts/an-dr-ai-slop')
Assert-Check 'concept name lacks its type' 1 "is a concept, so its name needs 'concept-'"

New-Fixture
Set-Content -LiteralPath (Join-Path $fixtureRoot 'skills/concepts/an-dr-concept-ai-slop/helper.ps1') -Value '# helper'
Assert-Check 'concept with a script' 1 'a concept allows only SKILL.md and tests/'

New-Fixture
Edit-Fixture 'skills/actions/an-dr-dev-test/SKILL.md' 'an-dr.dependencies: ' 'an-dr.dependencies: an-dr-agents-repo-install '
Add-FixtureText 'skills/actions/an-dr-dev-test/SKILL.md' 'See `an-dr-agents-repo-install`.'
Assert-Check 'general skill depends on a repository skill' 1 'a skill of the repository itself'

New-Fixture
Edit-Fixture 'skills/actions/an-dr-dev-integrate/SKILL.md' 'commit-message an-dr-git-commit' 'commit-message'
Assert-Check 'undeclared skill' 1 'names an-dr-git-commit but does not declare it in dependencies'

New-Fixture
Edit-Fixture 'skills/actions/an-dr-dev-implement-adversarial-ut/SKILL.md' 'an-dr.dependencies: none' 'an-dr.dependencies: an-dr-dev-debug'
Assert-Check 'unused declaration' 1 'declares an-dr-dev-debug but never names it'

New-Fixture
Add-FixtureText 'skills/concepts/an-dr-concept-evidence-grounding/SKILL.md' 'See `an-dr-dev-implement-code` for more.'
Assert-Check 'prohibited skill names another' 1 'is PROHIBITED from depending on other skills but names an-dr-dev-implement-code'

New-Fixture
Edit-Fixture 'skills/actions/an-dr-dev-implement-adversarial-ut/SKILL.md' 'an-dr.dependencies: none' 'an-dr.dependencies: an-dr-dev-debug'
Add-FixtureText 'skills/actions/an-dr-dev-implement-adversarial-ut/SKILL.md' 'Pair it with `an-dr-dev-debug`.'
Edit-Fixture 'skills/actions/an-dr-dev-debug/SKILL.md' 'an-dr.dependencies: none' 'an-dr.dependencies: an-dr-dev-implement-adversarial-ut'
Add-FixtureText 'skills/actions/an-dr-dev-debug/SKILL.md' 'Pair it with `an-dr-dev-implement-adversarial-ut`.'
Assert-Check 'cycle is reported' 0 'an-dr-dev-debug -> an-dr-dev-implement-adversarial-ut -> an-dr-dev-debug'
Assert-Check 'cycle fails on request' 1 'an-dr-dev-debug -> an-dr-dev-implement-adversarial-ut -> an-dr-dev-debug' @('-FailOnCycle')

New-Fixture
Edit-Fixture 'skills/actions/an-dr-files-make-screengif/SKILL.md' 'pwsh <skill>/' 'pwsh agents/skills/an-dr-files-make-screengif/'
Assert-Check 'layout path' 1 'repository-layout path'

New-Fixture
New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'lib') | Out-Null
Set-Content -LiteralPath (Join-Path $fixtureRoot 'lib/Shared.psm1') -Value '# shared'
Assert-Check 'root code' 1 'code outside skills/'

New-Fixture
Assert-Check 'all skills have test suites, including concepts' 0 'Registration check passed' @('-RequireTests')

New-Fixture
Rename-Item -LiteralPath (Join-Path $fixtureRoot 'skills/actions/an-dr-dev-debug/tests') -NewName 'tests-disabled'
Assert-Check 'missing tests folder' 1 'missing tests/cases.json' @('-RequireTests')

New-Fixture
Rename-Item -LiteralPath (Join-Path $fixtureRoot 'skills/concepts/an-dr-concept-ai-slop/tests/cases.json') -NewName 'cases-disabled.json'
Assert-Check 'missing concept cases' 1 'missing tests/cases.json' @('-RequireTests')

Remove-Fixture
Write-Output 'check-registration tests passed (17 cases).'
