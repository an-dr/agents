#Requires -Version 7
<# Vendored syntax baseline, owned by this skill. This is not runtime coverage. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scripts = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '..') -Recurse -File |
    Where-Object Extension -in @('.ps1', '.psm1'))
foreach ($script in $scripts) {
    $tokens = $null
    $parseErrors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) { throw "$($script.Name): $($parseErrors.Message -join '; ')" }
}
Write-Output "Syntax checks passed ($($scripts.Count) scripts). Runtime behavior is not established by this check."
