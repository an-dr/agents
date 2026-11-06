#Requires -Version 7
<# Render one diagram in a temporary page; skipped when no Chrome, Edge, or Chromium is installed. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '../render-mermaid.ps1'
$browser = foreach ($name in 'google-chrome', 'chromium', 'chromium-browser', 'microsoft-edge', 'chrome', 'msedge') {
    $command = Get-Command $name -ErrorAction SilentlyContinue
    if ($command) { $command.Source; break }
}
$installed = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
if (-not $browser -and -not $installed) {
    Write-Output 'render-mermaid test skipped: no browser installed.'
    exit 0
}

# An absolute path in the system temp folder: on Linux and macOS it starts with "/", which
# [Uri] alone parses as a relative URI and the browser never receives the page.
$work = Join-Path ([IO.Path]::GetTempPath()) "test-render-mermaid-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $page = Join-Path $work 'page.html'
    $html = "<html><head></head><body><pre class=`"mermaid`">flowchart TB`n  A[`"Start`"] --&gt; B[`"End`"]</pre></body></html>"
    [IO.File]::WriteAllText($page, $html, [Text.UTF8Encoding]::new($false))
    $output = (& pwsh -NoProfile -NonInteractive -File $scriptPath -Path $page 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Rendering failed: $output" }
    $result = [IO.File]::ReadAllText($page)
    if (-not $result.Contains('<svg')) { throw 'No SVG was rendered.' }
    if ($result.Contains('<pre class="mermaid">')) { throw 'The source block was not replaced by a figure.' }
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Output 'render-mermaid tests passed (2 checks).'
