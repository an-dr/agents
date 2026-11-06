#Requires -Version 7
<# Runs regression cases for the formatter and the checker's table alignment rule. #>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$fixtureDirectory = Join-Path ([IO.Path]::GetTempPath()) 'an-dr-markdown-format-tests'
New-Item -ItemType Directory -Path $fixtureDirectory -Force | Out-Null
$formatter = Join-Path $PSScriptRoot '../format-markdown.ps1'
$checker = Join-Path $PSScriptRoot '../check-markdown.ps1'
$cases = @(
    @{ Name = 'aligns'; In = "| A | Long header |`n| --- | --- |`n| value | x |"; Out = "| A     | Long header |`n| ----- | ----------- |`n| value | x           |" }
    @{ Name = 'markers'; In = "| A | B | C |`n| :--- | ---: | :-: |`n| one | two | three |"; Out = "| A   | B   | C     |`n| :-- | --: | :---: |`n| one | two | three |" }
    @{ Name = 'escaped-pipe'; In = "| A |`n| --- |`n| x\|y |"; Out = "| A    |`n| ---- |`n| x\|y |" }
    @{ Name = 'indented'; In = "- item`n`n  | A |`n  | --- |`n  | long |"; Out = "- item`n`n  | A    |`n  | ---- |`n  | long |" }
    @{ Name = 'fence-kept'; In = "``````text`n| A |`n| --- |`n| long |`n``````"; Out = "``````text`n| A |`n| --- |`n| long |`n``````" }
    @{ Name = 'comment-kept'; In = "<!--`n| A |`n| --- |`n| long |`n-->"; Out = "<!--`n| A |`n| --- |`n| long |`n-->" }
    @{ Name = 'trailing-space'; In = 'Prose.   '; Out = 'Prose.' }
)

$failures = @()
foreach ($case in $cases) {
    $fixture = Join-Path $fixtureDirectory ($case.Name + '.md')
    [IO.File]::WriteAllText($fixture, "# Example`n`n$($case.In)`n")
    & pwsh -NoProfile -File $formatter -Path $fixture | Out-Null
    $first = [IO.File]::ReadAllText($fixture)
    & pwsh -NoProfile -File $formatter -Path $fixture | Out-Null
    $second = [IO.File]::ReadAllText($fixture)
    $check = & pwsh -NoProfile -File $checker -Path $fixture 2>&1
    $checkExit = $LASTEXITCODE
    if ($first -cne "# Example`n`n$($case.Out)`n" -or $second -cne $first -or $checkExit -ne 0) {
        $failures += $case.Name
        Write-Output "FAIL $($case.Name): [$first] $check"
    }
}

$unaligned = Join-Path $fixtureDirectory 'unaligned.md'
[IO.File]::WriteAllText($unaligned, "# Example`n`n| A |`n| --- |`n| long |`n")
$output = & pwsh -NoProfile -File $checker -Path $unaligned 2>&1
if ($LASTEXITCODE -ne 1 -or "$output" -notmatch 'table\.align') {
    $failures += 'unaligned-rejected'
    Write-Output "FAIL unaligned-rejected: $output"
}

if ($failures.Count) { throw "$($failures.Count) Markdown format regression cases failed." }
Write-Output "All $($cases.Count + 1) Markdown format regression cases passed."
