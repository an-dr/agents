#Requires -Version 7
<#
    Validates every skill with skills-ref, the reference validator of the Agent Skills
    format. When skills-ref is not installed the script says how to install it and
    exits 0, because installing software is the user's decision; it exits 1 instead
    when -Require is given or the CI environment variable is set.
    Prints a Markdown table of problems and exits 1 when any skill fails.
#>
[CmdletBinding()]
param(
    [string]$Root = (Join-Path $PSScriptRoot '../../../..'),
    [switch]$Require
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path -LiteralPath $Root).ProviderPath
$install = 'pipx install "git+https://github.com/agentskills/agentskills#subdirectory=skills-ref"'
$command = Get-Command 'skills-ref' -ErrorAction SilentlyContinue

if (-not $command) {
    Write-Output 'skills-ref is not installed, so the skills were not validated against the Agent Skills format.'
    Write-Output ''
    Write-Output 'Install it, once per machine:'
    Write-Output ''
    Write-Output '```powershell'
    Write-Output $install
    Write-Output '```'
    Write-Output ''
    Write-Output 'Without pipx, create a virtual environment and run `pip install` with the same git URL.'
    if ($Require -or $env:CI) { exit 1 }
    exit 0
}

$problems = [System.Collections.Generic.List[object]]::new()
$checked = 0
foreach ($file in Get-ChildItem -Path (Join-Path $Root 'skills/*/*/SKILL.md') | Sort-Object FullName) {
    $checked++
    $output = @(& $command.Source validate $file.Directory.FullName 2>&1)
    if ($LASTEXITCODE -ne 0) {
        $where = 'skills/' + $file.Directory.Parent.Name + '/' + $file.Directory.Name
        $problems.Add([pscustomobject]@{ Where = $where; What = (($output | ForEach-Object { "$_".Trim() }) -join ' ') })
    }
}

if ($problems.Count -eq 0) {
    Write-Output "skills-ref validated $checked skills."
    exit 0
}
Write-Output "skills-ref: $($problems.Count) of $checked skill(s) failed."
Write-Output ''
Write-Output '| Where | Problem |'
Write-Output '| --- | --- |'
foreach ($problem in $problems) {
    Write-Output "| ``$($problem.Where)`` | $($problem.What -replace '\|', '\|') |"
}
exit 1
