#Requires -Version 7
<#
.SYNOPSIS
    Inlines the dark-cockpit stylesheet into an HTML page so its problem levels render.

.DESCRIPTION
    Pages mark findings with the ck-* classes and tokens from ../assets/dark-cockpit.css, the HTML implementation of concept-dark-cockpit.
    This script places that stylesheet in the page's <head>, before the page's own
    styles, so the page can use the tokens and still override layout.

    - Skipped when the page uses no ck-* class, so every page can run it.
    - Idempotent: a block between the begin and end markers is replaced, never duplicated.
    - One owner: the palette lives only in the asset, so every page shows one fact one way.
#>
[CmdletBinding()]
param([Parameter(Mandatory, Position = 0)][string]$Path)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$begin = '<!-- docs-html-report:cockpit begin -->'
$end = '<!-- docs-html-report:cockpit end -->'

$page = (Resolve-Path -LiteralPath $Path).Path
$sheet = Join-Path $PSScriptRoot '../assets/dark-cockpit.css'
if (-not (Test-Path -LiteralPath $sheet)) {
    throw "Dark-cockpit stylesheet not found at $sheet."
}

$block = @"
$begin
<style>
$([IO.File]::ReadAllText($sheet).TrimEnd())
</style>
$end
"@

$html = [IO.File]::ReadAllText($page)
if ($html -notmatch '\bck-(critical|high|notice|info|ok|badge|item|quiet)\b') {
    Write-Output "$page marks no findings; the dark-cockpit stylesheet was not embedded."
    return
}
$pattern = [regex]::Escape($begin) + '[\s\S]*?' + [regex]::Escape($end)
if ($html -match $pattern) {
    $html = [regex]::Replace($html, $pattern, { param($m) $block })
}
else {
    # Before the page's first stylesheet, so its own rules can refine the shared ones.
    $match = [regex]::Match($html, '<!-- docs-html-report:brand begin -->|<style[\s>]|</head>', 'IgnoreCase')
    if (-not $match.Success) {
        throw "$page has no <head>; write the page as a complete HTML document first."
    }
    $html = $html.Substring(0, $match.Index) + $block + "`n" + $html.Substring($match.Index)
}
[IO.File]::WriteAllText($page, $html, [Text.UTF8Encoding]::new($false))
Write-Output "Embedded the dark-cockpit stylesheet into $page."
