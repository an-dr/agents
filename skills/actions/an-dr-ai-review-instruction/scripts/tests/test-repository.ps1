#Requires -Version 7
<# Run this skill's validators against the containing skill repository. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot 'skills/README.md'))) {
    Write-Output 'Repository checks not applicable outside the source skill repository.'
    return
}
$checker = Join-Path $PSScriptRoot '../check-references.ps1'
$arguments = @('-Path', $repositoryRoot)
$output = @(& pwsh -NoProfile -NonInteractive -File $checker @arguments 2>&1)
$output | ForEach-Object { Write-Output "$_" }
if ($LASTEXITCODE -ne 0) { throw 'check-references.ps1 failed.' }
Write-Output 'Repository validators passed.'
