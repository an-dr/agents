#Requires -Version 7
<#
.SYNOPSIS
    Creates the run directory a generated artifact is written into, and prints its path.

.DESCRIPTION
    Every review and report of one run lands under REPO/.artifacts/ai-<date>-<letter>/<kind>/,
    so the newest run sorts last and holds that run's whole output. The stamp format is
    owned by the Temporary artifacts rule in AGENTS.md.

    - One letter per run, A for the day's first: a run that lasts an hour still owns one
      directory, and the next run takes the next free letter.
    - Pass -Run for every later artifact of the same run, instead of letting a second call
      allocate a second letter.
    - REPO/.artifacts/.gitignore ignores everything beneath it, so a new artifact kind
      never needs a rule of its own.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][string]$Kind,
    [string]$Run,
    [string]$RepositoryRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-NextArtifactRunLetter {
    <# Returns the first unused letter in the order A, B, ... Z, AA, AB, ... #>
    param([Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Used)

    # Shorter letters always sort first, so Z is followed by AA rather than by AAA.
    $letter = 'A'
    while ($letter -cin $Used) {
        $characters = [char[]]$letter
        $index = $characters.Count - 1
        while ($index -ge 0 -and $characters[$index] -eq 'Z') {
            $characters[$index] = 'A'
            $index--
        }
        $letter = if ($index -lt 0) {
            'A' + (-join $characters)
        }
        else {
            $characters[$index] = [char]([int]$characters[$index] + 1)
            -join $characters
        }
    }
    return $letter
}

if ($Kind -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
    throw "Artifact kind must be lowercase words joined by hyphens, not '$Kind'."
}
if (-not $RepositoryRoot) {
    $RepositoryRoot = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $RepositoryRoot) {
        throw 'Run this script inside the repository the artifact belongs to, or pass -RepositoryRoot.'
    }
    $RepositoryRoot = $RepositoryRoot.Trim()
}

$artifactsRoot = Join-Path $RepositoryRoot '.artifacts'
if (-not $Run) {
    $date = (Get-Date).ToString('yyyy-MM-dd')
    $used = @()
    if (Test-Path -LiteralPath $artifactsRoot) {
        $used = @(
            Get-ChildItem -LiteralPath $artifactsRoot -Directory |
                ForEach-Object {
                    if ($_.Name -cmatch "^ai-$date-([A-Z]+)$") { $Matches[1] }
                }
        )
    }
    $Run = "$date-$(Get-NextArtifactRunLetter -Used $used)"
}
if ($Run -cnotmatch '^\d{4}-\d{2}-\d{2}-[A-Z]+$') {
    throw "Artifact run stamp must look like 2026-10-18-B, not '$Run'."
}

$directory = Join-Path $artifactsRoot "ai-$Run/$Kind"
New-Item -ItemType Directory -Force -Path $directory | Out-Null

$ignorePath = Join-Path $artifactsRoot '.gitignore'
if (-not (Test-Path -LiteralPath $ignorePath)) {
    [IO.File]::WriteAllText(
        $ignorePath,
        (@('# Managed generated artifacts', '*', '!.gitignore', '') -join [Environment]::NewLine),
        [Text.UTF8Encoding]::new($false)
    )
}

Write-Output $directory
