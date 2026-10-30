#Requires -Version 7
<# Run this skill's validators against the containing skill repository. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot 'skills/README.md'))) {
    Write-Output 'Repository checks not applicable outside the source skill repository.'
    return
}
$checker = Join-Path $PSScriptRoot '../check-registration.ps1'
$arguments = @('-Root', $repositoryRoot, '-FailOnCycle', '-RequireTests')
$output = @(& pwsh -NoProfile -NonInteractive -File $checker @arguments 2>&1)
$output | ForEach-Object { Write-Output "$_" }
if ($LASTEXITCODE -ne 0) { throw 'check-registration.ps1 failed.' }
$checker = Join-Path $PSScriptRoot '../check-skills.ps1'
$arguments = @('-Root', $repositoryRoot)
$output = @(& pwsh -NoProfile -NonInteractive -File $checker @arguments 2>&1)
$output | ForEach-Object { Write-Output "$_" }
if ($LASTEXITCODE -ne 0) { throw 'check-skills.ps1 failed.' }
$checker = Join-Path $PSScriptRoot '../check-skills-ref.ps1'
$arguments = @('-Root', $repositoryRoot)
$output = @(& pwsh -NoProfile -NonInteractive -File $checker @arguments 2>&1)
$output | ForEach-Object { Write-Output "$_" }
if ($LASTEXITCODE -ne 0) { throw 'check-skills-ref.ps1 failed.' }
Write-Output 'Repository validators passed.'
