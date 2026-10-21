#Requires -Version 7
<#
.SYNOPSIS
    Inlines the report brand stylesheet into an HTML page.

.DESCRIPTION
    Every report page takes its neutral palette, fonts, and element defaults from
    ../assets/brand.css. This script places that stylesheet in the page's <head>,
    before the page's own styles, so the page can use the --brand-* tokens.

    - Idempotent: a block between the begin and end markers is replaced, never duplicated.
    - Order-free with ui-dark-cockpit: the cockpit reads the --brand-* tokens through
      var() fallbacks, so either stylesheet may be embedded first.
#>
[CmdletBinding()]
param([Parameter(Mandatory, Position = 0)][string]$Path)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$begin = '<!-- docs-html-report:brand begin -->'
$end = '<!-- docs-html-report:brand end -->'

$page = (Resolve-Path -LiteralPath $Path).Path
$sheet = Join-Path $PSScriptRoot '../assets/brand.css'
if (-not (Test-Path -LiteralPath $sheet)) {
    throw "Brand stylesheet not found at $sheet."
}

$block = @"
$begin
<style>
$([IO.File]::ReadAllText($sheet).TrimEnd())
</style>
$end
"@

$html = [IO.File]::ReadAllText($page)
$pattern = [regex]::Escape($begin) + '[\s\S]*?' + [regex]::Escape($end)
if ($html -match $pattern) {
    $html = [regex]::Replace($html, $pattern, { param($m) $block })
}
else {
    # Before the page's first stylesheet, so its own rules can refine the brand defaults.
    $match = [regex]::Match($html, '<!-- ui-dark-cockpit begin -->|<style[\s>]|</head>', 'IgnoreCase')
    if (-not $match.Success) {
        throw "$page has no <head>; write the page as a complete HTML document first."
    }
    $html = $html.Substring(0, $match.Index) + $block + "`n" + $html.Substring($match.Index)
}
[IO.File]::WriteAllText($page, $html, [Text.UTF8Encoding]::new($false))
Write-Output "Embedded the report brand into $page."
