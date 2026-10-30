#Requires -Version 7
<# Runs regression cases for every reply form read-answers.ps1 accepts. #>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot '../../../../..')
$fixtureDirectory = Join-Path $repositoryRoot '.artifacts/ai-user-interaction-tests'
New-Item -ItemType Directory -Path $fixtureDirectory -Force | Out-Null
$reader = Join-Path $PSScriptRoot '../read-answers.ps1'

$questions = Join-Path $fixtureDirectory 'questions.json'
@{ questions = @(
        @{ id = 'Q1'; question = 'Storage?'; options = @(@{ label = 'SQLite file (Recommended)' }, @{ label = 'In-memory map' }, @{ label = 'Redis' }) }
        @{ id = 'Q2'; question = 'Refresh on?'; multiSelect = $true; options = @(@{ label = 'File change' }, @{ label = 'Timer' }, @{ label = 'Manual command' }) }
        @{ id = 'Q3'; question = 'Delete build/?'; kind = 'confirm'; options = @(@{ label = 'No — keep them' }, @{ label = 'Yes — delete them' }) }
    ) } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $questions -Encoding utf8

$single = Join-Path $fixtureDirectory 'single.json'
@{ questions = @(@{ id = 'Q1'; kind = 'confirm'; question = 'Push?'; options = @(@{ label = 'Yes — push' }, @{ label = 'No — stay local' }) }) } |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $single -Encoding utf8

# Expected: status/choices per question, written as "status:choices".
$cases = @(
    @{ Name = 'compact'; Reply = '1a 2bc 3b'; Expect = @('answered:a', 'answered:b,c', 'answered:b') }
    @{ Name = 'commas'; Reply = '1a, 2b, 3a'; Expect = @('answered:a', 'answered:b', 'answered:a') }
    @{ Name = 'positional'; Reply = 'b a'; Expect = @('answered:b', 'answered:a', 'open:') }
    @{ Name = 'colon-and-q'; Reply = 'Q1: c Q3 y'; Expect = @('answered:c', 'open:', 'answered:b') }
    @{ Name = 'label'; Reply = '1: redis 3: no'; Expect = @('answered:c', 'open:', 'answered:a') }
    @{ Name = 'native-label'; Reply = '1: SQLite file (Recommended)'; Expect = @('answered:a', 'open:', 'open:') }
    @{ Name = 'custom-text'; Reply = '2: only on Mondays'; Expect = @('open:', 'custom:', 'open:') }
    @{ Name = 'two-for-single'; Reply = '1ab'; Expect = @('ambiguous:', 'open:', 'open:') }
    @{ Name = 'unknown-key'; Reply = '1z'; Expect = @('custom:', 'open:', 'open:') }
    @{ Name = 'empty'; Reply = ''; Expect = @('open:', 'open:', 'open:') }
    @{ Name = 'single-yes'; File = $single; Reply = 'yes'; Expect = @('answered:a') }
    @{ Name = 'single-n'; File = $single; Reply = 'n'; Expect = @('answered:b') }
)

$failures = @()
foreach ($case in $cases) {
    $file = if ($case.File) { $case.File } else { $questions }
    $out = Join-Path $fixtureDirectory "$($case.Name).answers.json"
    & $reader -Questions $file -Reply $case.Reply -Out $out | Out-Null
    $actual = @((Get-Content -LiteralPath $out -Raw | ConvertFrom-Json).answers | ForEach-Object { "$($_.status):$(@($_.choices) -join ',')" })
    if (($actual -join '|') -ne ($case.Expect -join '|')) {
        $failures += $case.Name
        Write-Output "FAIL $($case.Name): got $($actual -join ' | '), expected $($case.Expect -join ' | ')"
    }
}
if ($failures.Count) { throw "$($failures.Count) of $($cases.Count) answer cases failed." }
Write-Output "All $($cases.Count) answer cases passed."
