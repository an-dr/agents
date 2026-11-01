#Requires -Version 7
<#
.SYNOPSIS
    Copies a finished artifact to <kind>-latest beside the kind folders, and prints the copies.

.DESCRIPTION
    Given REPO/.artifacts-temp/ai/<kind>/<kind>-<stamp>.<extension>, every file of that
    stamp is copied to REPO/.artifacts-temp/ai/<kind>-latest.<extension>, after the previous
    <kind>-latest.* files are removed. Copies, not links: links need extra rights on Windows.
#>
[CmdletBinding()]
param([Parameter(Mandatory, Position = 0)][string]$Path)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$file = Get-Item -LiteralPath $Path
$kind = $file.Directory.Name
$aiRoot = $file.Directory.Parent
if ($aiRoot.Name -cne 'ai' -or $aiRoot.Parent.Name -cne '.artifacts-temp' -or
    $file.Name -cnotmatch "^$([regex]::Escape($kind))-(\d{4}-\d{2}-\d{2}_\d{2}-\d{2}(-\d+)?)\.") {
    throw "Not an artifact from new-artifact-path.ps1: $Path"
}
$stem = "$kind-$($Matches[1])"

Get-ChildItem -LiteralPath $aiRoot.FullName -File -Filter "$kind-latest.*" | Remove-Item -Force
foreach ($source in Get-ChildItem -LiteralPath $file.Directory.FullName -File -Filter "$stem.*") {
    $target = Join-Path $aiRoot.FullName ("$kind-latest" + $source.Name.Substring($stem.Length))
    Copy-Item -LiteralPath $source.FullName -Destination $target
    Write-Output $target
}
