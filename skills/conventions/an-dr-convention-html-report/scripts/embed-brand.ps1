#Requires -Version 7
<#
.SYNOPSIS
    Inlines the report brand stylesheet into an HTML page.

.DESCRIPTION
    Every report page takes its neutral palette, fonts, and element defaults from
    ../assets/brand.css. This script places that stylesheet in the page's <head>,
    before the page's own styles, so the page can use the --brand-* tokens.

    It also inserts the theme switch at the start of the <body>, so every page offers
    the same reading modes:

    - Auto / Light / Dark: sets data-theme on the root element, which the brand, the
      dark-cockpit levels, and the Mermaid diagrams all follow; remembered per browser.
    - Print: switches to light and opens every collapsed <details> before printing,
      and restores both afterwards. The brand's print rules force the light palette
      even when this script never ran.

    - Idempotent: blocks between the begin and end markers are replaced, never duplicated.
    - Order-free with the dark-cockpit sheet: the cockpit reads the --brand-* tokens through
      var() fallbacks, so either stylesheet may be embedded first.
#>
[CmdletBinding()]
param([Parameter(Mandatory, Position = 0)][string]$Path)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$begin = '<!-- an-dr-convention-html-report:brand begin -->'
$end = '<!-- an-dr-convention-html-report:brand end -->'

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
    $match = [regex]::Match($html, '<!-- an-dr-convention-html-report:cockpit begin -->|<style[\s>]|</head>', 'IgnoreCase')
    if (-not $match.Success) {
        throw "$page has no <head>; write the page as a complete HTML document first."
    }
    $html = $html.Substring(0, $match.Index) + $block + "`n" + $html.Substring($match.Index)
}

$themeBegin = '<!-- an-dr-convention-html-report:theme begin -->'
$themeEnd = '<!-- an-dr-convention-html-report:theme end -->'
$theme = @"
$themeBegin
<button type="button" class="brand-theme" id="brand-theme" title="Switch between automatic, light, and dark themes">Theme: auto</button>
<script>
(function () {
  var root = document.documentElement, key = 'docs-html-report-theme';
  var modes = ['auto', 'light', 'dark'];
  var button = document.getElementById('brand-theme');
  function current() { return root.getAttribute('data-theme') || 'auto'; }
  function apply(mode) {
    if (mode === 'auto') root.removeAttribute('data-theme'); else root.setAttribute('data-theme', mode);
    button.textContent = 'Theme: ' + current();
  }
  var saved = null;
  try { saved = localStorage.getItem(key); } catch (e) {}
  apply(modes.indexOf(saved) >= 0 ? saved : current());
  button.addEventListener('click', function () {
    var next = modes[(modes.indexOf(current()) + 1) % modes.length];
    apply(next);
    try { localStorage.setItem(key, next); } catch (e) {}
  });
  // Paper is always light, and nothing on it may stay folded away.
  var before = null, opened = [];
  window.addEventListener('beforeprint', function () {
    before = current();
    if (before !== 'light') root.setAttribute('data-theme', 'light');
    opened = Array.prototype.slice.call(document.querySelectorAll('details:not([open])'));
    opened.forEach(function (d) { d.open = true; });
  });
  window.addEventListener('afterprint', function () {
    if (before) apply(before);
    opened.forEach(function (d) { d.open = false; });
    before = null; opened = [];
  });
})();
</script>
$themeEnd
"@
$themePattern = [regex]::Escape($themeBegin) + '[\s\S]*?' + [regex]::Escape($themeEnd)
if ($html -match $themePattern) {
    $html = [regex]::Replace($html, $themePattern, { param($m) $theme })
}
else {
    $body = [regex]::Match($html, '<body[^>]*>', 'IgnoreCase')
    if (-not $body.Success) {
        throw "$page has no <body>; write the page as a complete HTML document first."
    }
    $at = $body.Index + $body.Length
    $html = $html.Substring(0, $at) + "`n" + $theme + $html.Substring($at)
}
[IO.File]::WriteAllText($page, $html, [Text.UTF8Encoding]::new($false))
Write-Output "Embedded the report brand and theme switch into $page."
