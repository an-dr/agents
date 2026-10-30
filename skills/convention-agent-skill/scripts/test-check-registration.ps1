#Requires -Version 7
<# Breaks a copy of the repository one way at a time and expects check-registration.ps1 to name each break. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).ProviderPath
$checker = Join-Path $PSScriptRoot 'check-registration.ps1'
$fixtureRoot = Join-Path $repositoryRoot '.artifacts/test-check-registration'

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
    Copy-Item -LiteralPath (Join-Path $repositoryRoot 'AGENTS.md') -Destination $fixtureRoot
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
New-Item -ItemType Directory -Path (Join-Path $fixtureRoot "skills/$extra") | Out-Null
Set-Content -LiteralPath (Join-Path $fixtureRoot "skills/$extra/SKILL.md") -Value "---`nname: $extra`n---"
Assert-Check 'unregistered folder' 1 'missing from the AGENTS.md skill table'

New-Fixture
Edit-Fixture 'skills/README.md' '| Compose and record a commit' '| Write a commit'
Assert-Check 'differing use' 1 'one-line use differs'

New-Fixture
Edit-Fixture 'skills/git-integrate/SKILL.md' 'dev-workflow-clean-branch git-commit' 'dev-workflow-clean-branch'
Assert-Check 'undeclared skill' 1 'names git-commit but does not declare it in dependencies'

New-Fixture
Edit-Fixture 'skills/ut-adversarial/SKILL.md' 'dependencies: none' 'dependencies: dev-debug'
Assert-Check 'unused declaration' 1 'declares dev-debug but never names it'

New-Fixture
Add-FixtureText 'skills/concept-evidence-grounding/SKILL.md' 'See dev-build for more.'
Assert-Check 'prohibited skill names another' 1 'is PROHIBITED from depending on other skills but names dev-build'

New-Fixture
Edit-Fixture 'skills/ut-adversarial/SKILL.md' 'dependencies: none' 'dependencies: dev-debug'
Add-FixtureText 'skills/ut-adversarial/SKILL.md' 'Pair it with dev-debug.'
Edit-Fixture 'skills/dev-debug/SKILL.md' 'dependencies: none' 'dependencies: ut-adversarial'
Add-FixtureText 'skills/dev-debug/SKILL.md' 'Pair it with ut-adversarial.'
Assert-Check 'cycle is reported' 0 'dev-debug -> ut-adversarial -> dev-debug'
Assert-Check 'cycle fails on request' 1 'dev-debug -> ut-adversarial -> dev-debug' @('-FailOnCycle')

New-Fixture
Edit-Fixture 'skills/docs-gif/SKILL.md' 'pwsh <skill>/' 'pwsh agents/skills/docs-gif/'
Assert-Check 'layout path' 1 'repository-layout path'

New-Fixture
New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'lib') | Out-Null
Set-Content -LiteralPath (Join-Path $fixtureRoot 'lib/Shared.psm1') -Value '# shared'
Assert-Check 'root code' 1 'code outside skills/'

Remove-Fixture
Write-Output 'check-registration tests passed (10 cases).'
