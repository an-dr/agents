#Requires -Version 7
<# Builds the graph of a small fixture tree and expects arrows, group titles, dashed undeclared skills, and a stable markdown block. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).ProviderPath
$script = Join-Path $PSScriptRoot 'build-dependencies.ps1'
$fixtureRoot = Join-Path $repositoryRoot '.artifacts/test-build-dependencies'

function Remove-Fixture {
    # Windows indexers and scanners can briefly hold a freshly written file, so retry.
    for ($attempt = 1; $attempt -le 8; $attempt++) {
        try { Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction Stop; return }
        catch { if ($attempt -eq 8) { throw }; Start-Sleep -Milliseconds 500 }
    }
}

function New-Skill([string]$Category, [string]$Name, [string]$Dependencies) {
    $directory = Join-Path $fixtureRoot "skills/$Category/$Name"
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $metadata = if ($Dependencies) { "metadata:`n  an-dr.dependencies: $Dependencies`n" } else { '' }
    [IO.File]::WriteAllText((Join-Path $directory 'SKILL.md'), "---`nname: $Name`ndescription: Test. Use when testing.`n$metadata---`n`n# $Name`n")
}

function Assert-Run([string]$Case, [int]$ExpectedExit, [string]$ExpectedText, [string[]]$Arguments = @()) {
    $output = (& pwsh -NoProfile -File $script -Root $fixtureRoot @Arguments) -join "`n"
    if ($LASTEXITCODE -ne $ExpectedExit) { throw "$Case`: exit $LASTEXITCODE, expected $ExpectedExit.`n$output" }
    if ($ExpectedText -and -not $output.Contains($ExpectedText)) { throw "$Case`: output lacks '$ExpectedText'.`n$output" }
}

if (Test-Path -LiteralPath $fixtureRoot) { Remove-Fixture }
New-Item -ItemType Directory -Path $fixtureRoot | Out-Null
New-Skill 'actions' 'alpha' 'beta gamma'
New-Skill 'actions' 'beta' 'none'
New-Skill 'concepts' 'gamma' 'PROHIBITED'
New-Skill '_repo' 'delta' ''

Assert-Run 'arrows' 0 'alpha --> beta & gamma'
Assert-Run 'group title' 0 'subgraph g_repo["Repo"]'
Assert-Run 'undeclared is marked' 0 'class delta undeclared'
Assert-Run 'undeclared is listed' 0 'Skills without an-dr.dependencies (1)'
Assert-Run 'check fails on an undeclared skill' 1 'delta' @('-Check')

$readme = Join-Path $fixtureRoot 'README.md'
[IO.File]::WriteAllText($readme, "# Title`n`n<!-- skill-dependencies begin -->`nold`n<!-- skill-dependencies end -->`n`nTail.`n")
Assert-Run 'markdown is rebuilt' 0 'Rebuilt the dependency diagram' @('-Markdown', $readme)
$text = [IO.File]::ReadAllText($readme)
if (-not $text.Contains('alpha --> beta & gamma') -or $text.Contains('old') -or -not $text.Contains('Tail.')) { throw "markdown block was not replaced in place.`n$text" }

Assert-Run 'check fails only on the undeclared skill' 1 'Skills without' @('-Markdown', $readme, '-Check')
New-Skill '_repo' 'delta' 'beta'
Assert-Run 'check on a stale block' 1 'is stale' @('-Markdown', $readme, '-Check')
Assert-Run 'rebuild after a change' 0 'Rebuilt' @('-Markdown', $readme)
Assert-Run 'check after the rebuild' 0 'is current' @('-Markdown', $readme, '-Check')
Assert-Run 'rebuild is idempotent' 0 'Rebuilt' @('-Markdown', $readme)
if (-not [IO.File]::ReadAllText($readme).Contains('delta --> beta')) { throw 'rebuilt block lacks the new arrow.' }

[IO.File]::WriteAllText($readme, "no markers`n")
$failed = $false
try { & pwsh -NoProfile -File $script -Root $fixtureRoot -Markdown $readme *> $null; $failed = $LASTEXITCODE -ne 0 } catch { $failed = $true }
if (-not $failed) { throw 'a markdown file without markers must fail.' }

Remove-Fixture
Write-Output 'build-dependencies tests passed (12 cases).'
