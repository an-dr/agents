#Requires -Version 7
<#
.SYNOPSIS
    Renders a report's Mermaid diagrams to inline SVG, each with a button that copies its source.

.DESCRIPTION
    A report's diagrams are <pre class="mermaid"> blocks, whichever skill wrote the page.
    This script renders every one with the vendored build in ../assets/mermaid.min.js inside
    a headless Chrome or Edge, and replaces the block with a figure holding:

    - a light and a dark SVG, so the diagram follows data-theme on the root element, else
      the system setting, without any script running in the reader's browser;
    - a "Copy Mermaid" button and the source in a hidden <pre>, so a reader can take the
      diagram into an editor or another document.

    - Static: the page carries no 2.5 MB renderer, and a host that renders Mermaid itself
      finds no <pre class="mermaid"> left to render twice.
    - Idempotent: a rendered figure keeps its source, so a rerun renders it again from that
      source, and the shared style and copy script between the markers is replaced.
    - Strict: a diagram that fails to parse stops the script with its number and Mermaid's
      message, and the page is left unchanged.
    - Offline: no CDN and no npm; only a locally installed Chromium-based browser.

    Pinned version: Mermaid 11.4.1. To update, replace assets/mermaid.min.js and the
    version below.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)][string]$Path,
    # A Chromium-based browser; found automatically when omitted.
    [string]$Browser
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$version = '11.4.1'
$begin = '<!-- an-dr-convention-html-report:mermaid begin -->'
$end = '<!-- an-dr-convention-html-report:mermaid end -->'
$figureBegin = '<!-- an-dr-convention-html-report:diagram begin -->'
$figureEnd = '<!-- an-dr-convention-html-report:diagram end -->'
# Pages embedded before this skill existed carry the old owner's markers.
$legacyOwner = 'dev-change-report'

function Find-Browser {
    if ($Browser) {
        if (-not (Test-Path -LiteralPath $Browser)) { throw "Browser not found at $Browser." }
        return $Browser
    }
    $candidates = @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
        "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
        '/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge'
    )
    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate }
    }
    foreach ($name in 'google-chrome', 'chromium', 'chromium-browser', 'microsoft-edge', 'chrome', 'msedge') {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    throw 'No Chrome, Edge, or Chromium found. Install one, or pass its executable with -Browser.'
}

function ConvertTo-ScriptJson([object]$Value) {
    # "<" escaped so no value can close the inline script that carries it.
    ($Value | ConvertTo-Json -Compress -Depth 5 -AsArray) -replace '<', '<'
}

function Invoke-MermaidRender([string[]]$Sources) {
    $library = Join-Path $PSScriptRoot '../assets/mermaid.min.js'
    if (-not (Test-Path -LiteralPath $library)) { throw "Mermaid build not found at $library." }

    $work = Join-Path ([IO.Path]::GetTempPath()) "render-mermaid-$([guid]::NewGuid())"
    New-Item -ItemType Directory -Path $work | Out-Null
    try {
        Copy-Item -LiteralPath $library (Join-Path $work 'mermaid.min.js')
        $harness = @"
<!DOCTYPE html>
<html><head><meta charset="utf-8"></head><body>
<div id="result"></div>
<script src="mermaid.min.js"></script>
<script>
(async function () {
  var sources = $(ConvertTo-ScriptJson $Sources);
  // Some diagram types name markers with fixed ids such as "arrowhead". Both theme copies sit
  // on one page, and a reference to the hidden copy's marker draws nothing, so every id is
  // made unique to its SVG.
  function scope(svg, prefix) {
    var ids = [], pattern = /\sid="([^"]+)"/g, found;
    while ((found = pattern.exec(svg))) if (found[1] !== prefix) ids.push(found[1]);
    ids.sort(function (a, b) { return b.length - a.length; });
    ids.forEach(function (id) {
      var escaped = id.replace(/[.*+?^`${}()|[\]\\]/g, '\\`$&');
      svg = svg.replace(new RegExp('(\\sid="|#)' + escaped + '(?![\\w-])', 'g'), '`$1' + prefix + '-' + id);
    });
    return svg;
  }
  var results = [];
  for (var i = 0; i < sources.length; i++) {
    var entry = { light: null, dark: null, error: null };
    for (var pass of [['light', 'default'], ['dark', 'dark']]) {
      try {
        mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: pass[1] });
        var prefix = 'report-diagram-' + (i + 1) + '-' + pass[0];
        entry[pass[0]] = scope((await mermaid.render(prefix, sources[i])).svg, prefix);
      } catch (error) {
        entry.error = String(error && error.message || error);
      }
    }
    results.push(entry);
  }
  // Base64, so the dumped DOM carries the SVG markup without any HTML escaping to undo.
  var json = JSON.stringify(results);
  var bytes = new TextEncoder().encode(json), text = '';
  for (var b = 0; b < bytes.length; b++) text += String.fromCharCode(bytes[b]);
  document.getElementById('result').textContent = 'RESULT:' + btoa(text) + ':END';
})();
</script>
</body></html>
"@
        $page = Join-Path $work 'render.html'
        [IO.File]::WriteAllText($page, $harness, [Text.UTF8Encoding]::new($false))

        $arguments = @('--headless=new',
            "--user-data-dir=$(Join-Path $work 'profile')", '--allow-file-access-from-files',
            '--virtual-time-budget=60000', '--dump-dom', ([Uri]$page).AbsoluteUri)
        # Redirected to a file: Chrome's large dump arrives empty through a PowerShell pipe.
        $output = Join-Path $work 'dom.html'
        Start-Process -FilePath (Find-Browser) -ArgumentList $arguments -Wait -NoNewWindow `
            -RedirectStandardOutput $output -RedirectStandardError (Join-Path $work 'browser.log')
        $dom = (Test-Path -LiteralPath $output) ? [IO.File]::ReadAllText($output) : ''
        $match = [regex]::Match($dom, 'RESULT:([A-Za-z0-9+/=]*):END')
        if (-not $match.Success) { throw 'The browser did not finish rendering the diagrams.' }
        $json = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($match.Groups[1].Value))
        return @($json | ConvertFrom-Json)
    }
    finally {
        Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$report = (Resolve-Path -LiteralPath $Path).Path
$html = [IO.File]::ReadAllText($report)

# Drop the shared block, including a client-side renderer embedded by an older version.
$sharedPattern = '\s*<!-- (?:an-dr-convention-html-report|' + [regex]::Escape($legacyOwner) + '):mermaid begin -->[\s\S]*?<!-- (?:an-dr-convention-html-report|' + [regex]::Escape($legacyOwner) + '):mermaid end -->'
$html = [regex]::Replace($html, $sharedPattern, '')

$diagramPattern = [regex]::Escape($figureBegin) + '[\s\S]*?<pre class="mermaid-source"[^>]*>([\s\S]*?)</pre>[\s\S]*?' + [regex]::Escape($figureEnd) +
    '|<pre class="mermaid"[^>]*>([\s\S]*?)</pre>'
$found = [regex]::Matches($html, $diagramPattern)
$sources = @($found | ForEach-Object {
        $raw = $_.Groups[1].Success ? $_.Groups[1].Value : $_.Groups[2].Value
        [Net.WebUtility]::HtmlDecode($raw).Trim()
    })

if ($sources.Count -eq 0) {
    [IO.File]::WriteAllText($report, $html, [Text.UTF8Encoding]::new($false))
    Write-Output "No diagrams in $report; nothing rendered."
    return
}

$rendered = Invoke-MermaidRender $sources
$failures = @(for ($i = 0; $i -lt $rendered.Count; $i++) {
        if ($rendered[$i].error) { "diagram $($i + 1): $($rendered[$i].error)" }
    })
if ($failures.Count -gt 0) {
    throw "Mermaid could not render $($failures.Count) diagram(s); $report is unchanged.`n$($failures -join "`n")"
}

# A hashtable, because the replacement block runs in its own scope.
$state = @{ Index = 0 }
$html = [regex]::Replace($html, $diagramPattern, {
        param($m)
        $source = [Net.WebUtility]::HtmlEncode($sources[$state.Index])
        $result = $rendered[$state.Index]
        $state.Index++
        @"
$figureBegin
<figure class="report-diagram">
<div class="report-diagram-view report-diagram-light">$($result.light)</div>
<div class="report-diagram-view report-diagram-dark">$($result.dark)</div>
<button type="button" class="report-diagram-copy">Copy Mermaid</button>
<pre class="mermaid-source" hidden>$source</pre>
</figure>
$figureEnd
"@
    })

$shared = @"
$begin
<!-- Diagrams rendered to SVG with Mermaid $version by the an-dr-convention-html-report skill -->
<style>
.report-diagram { position: relative; margin: 1rem 0; overflow-x: auto; }
.report-diagram-view svg { max-width: 100%; height: auto; }
.report-diagram-dark { display: none; }
:root[data-theme="dark"] .report-diagram-light { display: none; }
:root[data-theme="dark"] .report-diagram-dark { display: block; }
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) .report-diagram-light { display: none; }
  :root:not([data-theme="light"]) .report-diagram-dark { display: block; }
}
.report-diagram-copy {
  position: absolute; top: 0.25rem; right: 0.25rem; font: inherit; font-size: 0.8rem;
  padding: 0.15rem 0.5rem; cursor: pointer; color: var(--brand-text, inherit);
  background: var(--brand-background, transparent); border: 1px solid currentColor; border-radius: 4px; opacity: 0.6;
}
.report-diagram-copy:hover, .report-diagram-copy:focus { opacity: 1; }
@media print {
  .report-diagram-copy { display: none; }
  .report-diagram .report-diagram-light { display: block !important; }
  .report-diagram .report-diagram-dark { display: none !important; }
}
</style>
<script>
(function () {
  function fallback(text) {
    var area = document.createElement('textarea');
    area.value = text;
    area.style.position = 'fixed';
    area.style.opacity = '0';
    document.body.appendChild(area);
    area.select();
    var ok = document.execCommand('copy');
    document.body.removeChild(area);
    return ok ? Promise.resolve() : Promise.reject();
  }
  document.querySelectorAll('.report-diagram-copy').forEach(function (button) {
    button.addEventListener('click', function () {
      var text = button.parentNode.querySelector('.mermaid-source').textContent;
      // The clipboard API needs a secure context, which a page opened from disk may not be.
      var copy = navigator.clipboard && window.isSecureContext ? navigator.clipboard.writeText(text) : fallback(text);
      copy.then(function () { button.textContent = 'Copied'; }, function () { button.textContent = 'Copy failed'; })
        .then(function () { setTimeout(function () { button.textContent = 'Copy Mermaid'; }, 1500); });
    });
  });
})();
</script>
$end
"@
if ($html -match '</body>') {
    $at = $html.LastIndexOf('</body>')
    $html = $html.Substring(0, $at) + $shared + "`n" + $html.Substring($at)
}
else {
    $html = $html.TrimEnd() + "`n" + $shared + "`n"
}
[IO.File]::WriteAllText($report, $html, [Text.UTF8Encoding]::new($false))
Write-Output "Rendered $($sources.Count) diagram(s) in $report to SVG with Mermaid $version."
