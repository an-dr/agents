#Requires -Version 7
<# Breaks a copy of the skills one way at a time and expects check-skills.ps1 to name each break. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).ProviderPath
$checker = Join-Path $PSScriptRoot 'check-skills.ps1'
$fixtureRoot = Join-Path $repositoryRoot '.artifacts/test-check-skills'

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
Edit-Fixture 'skills/dev-debug/SKILL.md' 'Use ' 'Apply '
Assert-Check 'no trigger sentence' 1 "description has no trigger sentence beginning 'Use '"

New-Fixture
Edit-Fixture 'skills/concept-single-authority/SKILL.md' '# Concept: single authority' '# Single authority'
Assert-Check 'concept title' 1 "must start with 'Concept: '"

New-Fixture
Edit-Fixture 'skills/dev-debug/SKILL.md' '# Debug' '# Convention: debug'
Assert-Check 'task title prefix' 1 'uses a concept or convention prefix on a task skill'

New-Fixture
Edit-Fixture 'skills/concept-single-authority/SKILL.md' '## Violations' '## Pitfalls'
Assert-Check 'concept without violations' 1 "has no '## Violations' section"

New-Fixture
Edit-Fixture 'skills/convention-commit-message/SKILL.md' '## Examples' '## Check again'
Add-Content -LiteralPath (Join-Path $fixtureRoot 'skills/convention-commit-message/SKILL.md') -Value "`n## Examples`n`nNone."
Add-Content -LiteralPath (Join-Path $fixtureRoot 'skills/convention-commit-message/SKILL.md') -Value "`n## Afterword`n`nNone."
Assert-Check 'examples not last' 1 "'## Examples' must be the last section"

New-Fixture
Add-Content -LiteralPath (Join-Path $fixtureRoot 'skills/dev-debug/SKILL.md') -Value (("filler`n") * 160)
Assert-Check 'too long' 1 'lines; split it or move logic into a script'

Remove-Fixture
Write-Output 'check-skills tests passed (6 cases).'
