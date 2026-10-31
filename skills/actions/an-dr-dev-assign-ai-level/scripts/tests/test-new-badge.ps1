#Requires -Version 7
<# Runtime coverage for new-badge.ps1: valid levels and styles, and rejected levels. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot '..' 'new-badge.ps1'

$markdown = @(& pwsh -NoProfile -NonInteractive -File $script -Level 3)[1]
$expected = '[![AI Level 3](https://ai-level.dev/badge/standard/3.svg)](https://ai-level.dev/level-3)'
if ($markdown -ne $expected) { throw "Unexpected Markdown badge: $markdown" }

$compact = @(& pwsh -NoProfile -NonInteractive -File $script -Level 0 -Style compact)[1]
if ($compact -notmatch '/badge/compact/0\.svg') { throw "Compact style missing: $compact" }

foreach ($bad in 5, -1) {
    $null = & pwsh -NoProfile -NonInteractive -File $script -Level $bad 2>&1
    if ($LASTEXITCODE -eq 0) { throw "Level $bad was accepted." }
}
Write-Output 'new-badge checks passed.'
