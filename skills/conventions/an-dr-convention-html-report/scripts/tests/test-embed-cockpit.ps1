#Requires -Version 7
<# Exercise the public in-memory interface without mutating repository fixtures. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '../embed-cockpit.ps1'
$css = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../../assets/dark-cockpit.css')).TrimEnd()
$marker = '<!-- an-dr-convention-html-report:cockpit begin -->'
$page = '<html><head><style>/* page-owned style */</style></head><body><div class="ck-notice">Keep $1 &amp; Unicode: café.</div></body></html>'

function Invoke-Embed([string]$Markup) {
    $output = (& pwsh -NoProfile -NonInteractive -File $scriptPath -Html $Markup 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Embedding failed: $output" }
    return $output
}

$result = Invoke-Embed $page
if (-not $result.Contains($css)) { throw 'The actual owned stylesheet was not embedded.' }
if ($result.IndexOf($marker) -ge $result.IndexOf('/* page-owned style */')) { throw 'The stylesheet must precede page styles.' }
if (-not $result.Contains('Keep $1 &amp; Unicode: café.')) { throw 'Page content was changed.' }
$again = Invoke-Embed $result
if ($again -cne $result -or [regex]::Matches($again, [regex]::Escape($marker)).Count -ne 1) { throw 'Embedding is not idempotent.' }
$plain = '<html><head></head><body>No findings.</body></html>'
if ((Invoke-Embed $plain) -cne $plain) { throw 'An unmarked page must remain unchanged.' }
$quiet = Invoke-Embed '<html><head></head><body><details class="ck-quiet">Passed checks</details></body></html>'
if (-not $quiet.Contains($marker)) { throw 'Quiet status containers still require the stylesheet.' }
$failure = (& pwsh -NoProfile -NonInteractive -File $scriptPath -Html '<body><div class="ck-high">Problem</div></body>' 2>&1) -join "`n"
if ($LASTEXITCODE -eq 0 -or -not $failure.Contains('has no <head>')) { throw "Missing-head input must fail clearly: $failure" }
Write-Output 'embed-cockpit tests passed (7 checks).'
