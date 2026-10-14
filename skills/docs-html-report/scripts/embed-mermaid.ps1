#Requires -Version 7
<#
.SYNOPSIS
    Inlines the pinned Mermaid build into an HTML report so its diagrams render anywhere.

.DESCRIPTION
    A report's diagrams are <pre class="mermaid"> blocks, whichever skill wrote the page.
    Nothing renders them in a local browser or an editor preview, so this script appends
    the vendored build from ../assets/mermaid.min.js and a small start-up script to the
    end of the page.

    - Idempotent: a block between the begin and end markers is replaced, never duplicated.
    - Offline: no CDN, so a report opened from disk renders the same as a published one.
    - Theme-aware: diagrams follow data-theme on the root element, else the system setting,
      and re-render when it changes.
    - Renamed after claiming: rendered blocks lose the "mermaid" class, so a host that
      renders Mermaid itself does not render them a second time.

    Pinned version: Mermaid 11.4.1. To update, replace assets/mermaid.min.js and the
    version below.
#>
[CmdletBinding()]
param([Parameter(Mandatory, Position = 0)][string]$Path)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$version = '11.4.1'
$begin = '<!-- docs-html-report:mermaid begin -->'
$end = '<!-- docs-html-report:mermaid end -->'
# Pages embedded before this skill existed carry the old owner's markers.
$legacyOwner = 'dev-change-report'

$report = (Resolve-Path -LiteralPath $Path).Path
$library = Join-Path $PSScriptRoot '../assets/mermaid.min.js'
if (-not (Test-Path -LiteralPath $library)) {
    throw "Mermaid build not found at $library."
}

# A literal "</script" inside the library would end the inline script early.
$code = [IO.File]::ReadAllText($library) -replace '</script', '<\/script'

$startup = @'
(function () {
  var dark = window.matchMedia('(prefers-color-scheme: dark)');
  function theme() {
    var chosen = document.documentElement.getAttribute('data-theme');
    if (chosen) return chosen === 'dark' ? 'dark' : 'default';
    return dark.matches ? 'dark' : 'default';
  }
  var blocks = Array.prototype.slice.call(document.querySelectorAll('pre.mermaid'));
  blocks.forEach(function (block) {
    block.setAttribute('data-mermaid-source', block.textContent);
    block.classList.remove('mermaid');
    block.classList.add('mermaid-diagram');
  });
  function render() {
    window.mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: theme() });
    blocks.forEach(function (block) {
      block.removeAttribute('data-processed');
      block.textContent = block.getAttribute('data-mermaid-source');
    });
    window.mermaid.run({ nodes: blocks }).catch(function (error) { console.error(error); });
  }
  render();
  dark.addEventListener('change', render);
  new MutationObserver(render).observe(document.documentElement, { attributes: true, attributeFilter: ['data-theme'] });
})();
'@

$block = @"
$begin
<!-- Mermaid $version, embedded by the docs-html-report skill -->
<script>
$code
</script>
<script>
$startup
</script>
$end
"@

$html = [IO.File]::ReadAllText($report)
$pattern = '<!-- (?:docs-html-report|' + [regex]::Escape($legacyOwner) + '):mermaid begin -->[\s\S]*?<!-- (?:docs-html-report|' + [regex]::Escape($legacyOwner) + '):mermaid end -->'
if ($html -match $pattern) {
    $html = [regex]::Replace($html, $pattern, { param($m) $block })
}
elseif ($html -match '</body>') {
    $index = $html.LastIndexOf('</body>')
    $html = $html.Substring(0, $index) + $block + "`n" + $html.Substring($index)
}
else {
    $html = $html.TrimEnd() + "`n" + $block + "`n"
}
[IO.File]::WriteAllText($report, $html, [Text.UTF8Encoding]::new($false))

$diagrams = ([regex]::Matches($html, '<pre class="mermaid')).Count
Write-Output "Embedded Mermaid $version into $report ($diagrams diagram(s))."
