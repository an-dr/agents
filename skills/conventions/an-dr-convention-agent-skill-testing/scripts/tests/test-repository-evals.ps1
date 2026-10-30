#Requires -Version 7
<# Discover and structurally validate skill evaluation data without invoking models. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
$checker = Join-Path $PSScriptRoot '../check-evals.ps1'
$suites = if (Test-Path -LiteralPath (Join-Path $repositoryRoot 'skills/README.md')) {
    @(Get-ChildItem -Path (Join-Path $repositoryRoot 'skills/*/*/evals/evals.json') -File | Sort-Object FullName)
} else {
    @(Get-Item -LiteralPath (Join-Path $PSScriptRoot '../../evals/evals.json'))
}
if ($suites.Count -eq 0) { throw 'No evaluation suites discovered.' }
foreach ($suite in $suites) {
    $output = @(& pwsh -NoProfile -NonInteractive -File $checker -Path $suite.FullName 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "$($suite.FullName): $($output -join [Environment]::NewLine)" }
}
Write-Output "$($suites.Count) discovered evaluation suites passed structural and archive checks. No agent evaluations ran."
