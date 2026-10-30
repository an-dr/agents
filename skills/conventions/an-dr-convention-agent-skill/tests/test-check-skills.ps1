#Requires -Version 7
<# Breaks a copy of the skills one way at a time and expects check-skills.ps1 to name each break. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).ProviderPath
$checker = Join-Path $PSScriptRoot '../scripts/check-skills.ps1'
$fixtureRoot = Join-Path $repositoryRoot '.artifacts/test-check-skills'

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

function Assert-Check([string]$Case, [int]$ExpectedExit, [string]$ExpectedText) {
    $output = (& pwsh -NoProfile -File $checker -Root $fixtureRoot) -join "`n"
    if ($LASTEXITCODE -ne $ExpectedExit) { throw "$Case`: exit $LASTEXITCODE, expected $ExpectedExit.`n$output" }
    if ($ExpectedText -and -not $output.Contains($ExpectedText)) { throw "$Case`: output lacks '$ExpectedText'.`n$output" }
}

New-Fixture
Assert-Check 'clean copy' 0 'Skill check passed'

New-Fixture
Edit-Fixture 'skills/actions/an-dr-dev-debug/SKILL.md' 'Use ' 'Apply '
Assert-Check 'no trigger sentence' 1 "description has no trigger sentence beginning 'Use '"

New-Fixture
Edit-Fixture 'skills/concepts/an-dr-concept-single-authority/SKILL.md' '# Concept: single authority' '# Single authority'
Assert-Check 'concept title' 1 "must start with 'Concept: '"

New-Fixture
Edit-Fixture 'skills/actions/an-dr-dev-debug/SKILL.md' '# Debug' '# Convention: debug'
Assert-Check 'action title prefix' 1 'uses a concept or convention prefix on an action'

New-Fixture
Edit-Fixture 'skills/concepts/an-dr-concept-single-authority/SKILL.md' '## Violations' '## Pitfalls'
Assert-Check 'concept without violations' 1 "has no '## Violations' section"

New-Fixture
Add-Content -LiteralPath (Join-Path $fixtureRoot 'skills/conventions/an-dr-convention-commit-message/SKILL.md') -Value "`n## Afterword`n`nNone."
Assert-Check 'examples not last' 1 "'## Examples' must be the last section"

New-Fixture
Add-Content -LiteralPath (Join-Path $fixtureRoot 'skills/actions/an-dr-dev-debug/SKILL.md') -Value (("filler`n") * 160)
Assert-Check 'too long' 1 'lines; split it or move logic into a script'

New-Fixture
Edit-Fixture 'skills/actions/an-dr-git-commit/SKILL.md' 'allowed-tools: PowerShell' "allowed-tools: PowerShell, Read`nuser-invocable: false"
Assert-Check 'unknown key and comma tools' 1 "frontmatter key 'user-invocable' is not part of the Agent Skills format"
Assert-Check 'comma separated tools' 1 'allowed-tools must be a space-separated string'

New-Fixture
Edit-Fixture 'skills/actions/an-dr-git-commit/SKILL.md' 'description: Compose and record' 'description: Note: compose and record'
Assert-Check 'yaml colon in description' 1 'invalid in an unquoted YAML value'

New-Fixture
Edit-Fixture 'skills/actions/an-dr-dev-debug/SKILL.md' '  an-dr.type: action' '  an-dr.other: x'
Assert-Check 'missing extension' 1 'metadata has no an-dr.type'

New-Fixture
Edit-Fixture 'skills/actions/an-dr-dev-debug/SKILL.md' 'license: MIT' 'license:'
Assert-Check 'missing license' 1 'has no license'

New-Fixture
Edit-Fixture 'skills/actions/an-dr-dev-debug/SKILL.md' '  version: "1.0.0"' '  version: latest'
Assert-Check 'bad version' 1 'must be a semantic version'

New-Fixture
Edit-Fixture 'skills/actions/an-dr-dev-debug/SKILL.md' "  author: Andrei Gramakov (an-dr)`n" ""
Assert-Check 'missing author' 1 'metadata has no author'

Remove-Fixture
Write-Output 'check-skills tests passed (13 cases).'
