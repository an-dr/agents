#Requires -Version 7
<# Breaks a copy of the skills one way at a time and expects check-scripts.ps1 to name each break. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).ProviderPath
$checker = Join-Path $PSScriptRoot 'check-scripts.ps1'
$fixtureRoot = Join-Path $repositoryRoot '.artifacts/test-check-scripts'

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
Assert-Check 'clean copy' 0 'Script check passed'

New-Fixture
Edit-Fixture 'skills/dev-workflow-integrate/scripts/integrate-2-squash.ps1' '#Requires -Version 7' '# no requirement'
Assert-Check 'missing requires' 1 "does not start with '#Requires -Version 7'"

New-Fixture
# Joined at run time so the checker does not flag this test file itself.
$up = '..' + '/..'
Edit-Fixture 'skills/dev-workflow-integrate/scripts/integrate-2-squash.ps1' '#Requires -Version 7' "#Requires -Version 7`nImport-Module (Join-Path `$PSScriptRoot '$up/git-commit/scripts/new-commit.ps1')"
Assert-Check 'sibling guess' 1 'guesses where git-commit is installed'

Remove-Fixture
Write-Output 'check-scripts tests passed (3 cases).'
