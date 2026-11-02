#Requires -Version 7
<#
.SYNOPSIS
    Prints the path a generated artifact is written to, creating its kind directory.

.DESCRIPTION
    Every artifact lands at REPO/.tmp-ai-gen/<kind>/<kind>-<YYYY-MM-DD_hh-mm>.<extension>,
    so one kind's history sorts by time in one folder. publish-latest.ps1 then copies the
    newest to REPO/.tmp-ai-gen/<kind>-latest.<extension>.

    - Only kinds listed in assets/kinds.txt are accepted: the folder holds skill outputs,
      not scratch files.
    - Without -Stamp the current minute is taken, with -2, -3, ... when that minute is used.
      Pass the printed stamp back as -Stamp for every other file of the same artifact,
      such as the HTML rendered from a review's JSON.
    - REPO/.tmp-ai-gen/.gitignore holds *, so git ignores the folder, itself included,
      and nothing needs a commit or a rule in the repository's own .gitignore.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][string]$Kind,
    [Parameter(Mandatory, Position = 1)][string]$Extension,
    [string]$Stamp,
    [string]$RepositoryRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$kinds = @(Get-Content -LiteralPath (Join-Path $PSScriptRoot '../assets/kinds.txt') | Where-Object { $_.Trim() })
if ($Kind -cnotin $kinds) {
    throw "Artifact kind '$Kind' is not registered in assets/kinds.txt ($($kinds -join ', '))."
}
$Extension = $Extension.TrimStart('.')
if ($Extension -cnotmatch '^[a-z0-9]+(\.[a-z0-9]+)*$') {
    throw "Artifact extension must be lowercase, such as html or questions.json, not '$Extension'."
}
if (-not $RepositoryRoot) {
    $RepositoryRoot = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $RepositoryRoot) {
        throw 'Run this script inside the repository the artifact belongs to, or pass -RepositoryRoot.'
    }
    $RepositoryRoot = $RepositoryRoot.Trim()
}

$tempRoot = Join-Path $RepositoryRoot '.tmp-ai-gen'
$directory = Join-Path $tempRoot $Kind
New-Item -ItemType Directory -Force -Path $directory | Out-Null

$ignorePath = Join-Path $tempRoot '.gitignore'
if (-not (Test-Path -LiteralPath $ignorePath)) {
    [IO.File]::WriteAllText(
        $ignorePath,
        (@('# Generated AI artifacts; nothing here is committed', '*', '') -join "`n"),
        [Text.UTF8Encoding]::new($false)
    )
}

if (-not $Stamp) {
    $minute = (Get-Date).ToString('yyyy-MM-dd_HH-mm')
    $Stamp = $minute
    $suffix = 1
    while (@(Get-ChildItem -LiteralPath $directory -Filter "$Kind-$Stamp.*").Count -gt 0) {
        $suffix++
        $Stamp = "$minute-$suffix"
    }
}
if ($Stamp -cnotmatch '^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}(-\d+)?$') {
    throw "Artifact stamp must look like 2026-11-01_14-32, not '$Stamp'."
}

Write-Output (Join-Path $directory "$Kind-$Stamp.$Extension")
