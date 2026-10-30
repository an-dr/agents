#Requires -Version 7
<# Breaks a copy of the repository one way at a time and expects check-registration.ps1 to name each break. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).ProviderPath
$checker = Join-Path $PSScriptRoot 'check-registration.ps1'
$fixtureRoot = Join-Path $repositoryRoot '.artifacts/test-check-registration'

function New-Fixture {
    if (Test-Path -LiteralPath $fixtureRoot) { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force }
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

function Assert-Check([string]$Case, [int]$ExpectedExit, [string]$ExpectedText) {
    $output = (& pwsh -NoProfile -File $checker -Root $fixtureRoot) -join "`n"
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
Edit-Fixture 'skills/git-integrate/SKILL.md' 'requires: dev-workflow-clean-branch git-commit' 'requires: git-commit'
Assert-Check 'undeclared skill' 1 'does not declare it in requires'

New-Fixture
Edit-Fixture 'skills/git-commit/SKILL.md' "name: git-commit" "name: git-commit`nmetadata:`n  requires: git-integrate"
Assert-Check 'cycle' 1 'depends back on it'

New-Fixture
# Joined at run time so the checker does not flag this test file itself.
$up = '..' + '/..'
Edit-Fixture 'skills/git-integrate/scripts/integrate-2-squash.ps1' '#Requires -Version 7' "#Requires -Version 7`nImport-Module (Join-Path `$PSScriptRoot '$up/git-commit/scripts/GitCommit.Format.psm1')"
Assert-Check 'sibling guess' 1 'guesses where git-commit is installed'

New-Fixture
Edit-Fixture 'skills/docs-gif/SKILL.md' 'pwsh <skill>/' 'pwsh agents/skills/docs-gif/'
Assert-Check 'layout path' 1 'repository-layout path'

New-Fixture
New-Item -ItemType Directory -Path (Join-Path $fixtureRoot 'lib') | Out-Null
Set-Content -LiteralPath (Join-Path $fixtureRoot 'lib/Shared.psm1') -Value '# shared'
Assert-Check 'root code' 1 'code outside skills/'

Remove-Item -LiteralPath $fixtureRoot -Recurse -Force
Write-Output 'check-registration tests passed (8 cases).'
