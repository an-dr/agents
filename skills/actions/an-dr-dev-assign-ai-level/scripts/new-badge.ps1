#Requires -Version 7
<#
    Prints the ai-level.dev badge for a level as Markdown and as HTML.
    Exits non-zero when the level is outside 0 to 4.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateRange(0, 4)][int]$Level,
    [ValidateSet('standard', 'compact')][string]$Style = 'standard'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$image = "https://ai-level.dev/badge/$Style/$Level.svg"
$page = "https://ai-level.dev/level-$Level"

Write-Output 'Markdown:'
Write-Output "[![AI Level $Level]($image)]($page)"
Write-Output 'HTML:'
Write-Output "<a href=`"$page`"><img src=`"$image`" alt=`"AI Level $Level`" /></a>"
