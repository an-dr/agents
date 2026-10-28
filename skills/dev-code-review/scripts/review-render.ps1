#Requires -Version 7
<# Renders canonical review JSON as one deterministic, self-contained HTML page. #>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ReviewPath,
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Review.Common.psm1') -Force

function ConvertTo-ReviewHtml {
    <# Escapes note text for HTML and renders `backtick` spans as inline code. #>
    param([AllowEmptyString()][string]$Value)

    $escaped = [Net.WebUtility]::HtmlEncode(($Value -replace '[\r\n]+', ' ').Trim())
    return $escaped -replace '`+([^`]+?)`+', '<code>$1</code>'
}

function Get-FindingSectionHtml {
    <# Renders one finding section with a fixed heading, or an explicit empty state. #>
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][string]$Level,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Notes
    )

    $html = [Collections.Generic.List[string]]::new()
    $html.Add("<section><h2>$Title</h2>")
    if ($Notes.Count -eq 0) {
        $html.Add('<p class="ck-quiet">None.</p>')
    }
    foreach ($note in $Notes) {
        $location = [Net.WebUtility]::HtmlEncode($note.file)
        if ($note.line) {
            $location = "${location}:$($note.line)"
        }
        $html.Add("<article class=""finding ck-item $Level"" id=""$($note.id)"">")
        $html.Add("<div class=""head""><span class=""ck-badge $Level"">$($note.id)</span><span class=""loc"">$location</span></div>")
        $html.Add("<p>$(ConvertTo-ReviewHtml -Value $note.text)</p>")
        if ($note.PSObject.Properties.Name -contains 'diagram') {
            $html.Add("<div class=""diagram""><pre class=""mermaid"">$([Net.WebUtility]::HtmlEncode($note.diagram))</pre></div>")
        }
        $html.Add("<p class=""fix""><span class=""tag"">Fix</span> $(ConvertTo-ReviewHtml -Value $note.recommendation)</p>")
        $html.Add('</article>')
    }
    $html.Add('</section>')
    return $html.ToArray()
}

$resolvedPath = Resolve-ReviewPath -Path $ReviewPath
$review = Read-ReviewJson -Path $resolvedPath
if (-not $OutputPath) {
    $OutputPath = [IO.Path]::ChangeExtension($resolvedPath, '.html')
}
elseif (-not [IO.Path]::IsPathRooted($OutputPath)) {
    $OutputPath = Join-Path (Get-Location) $OutputPath
}
$OutputPath = [IO.Path]::GetFullPath($OutputPath)
if ((Split-Path -Parent $OutputPath) -ne (Split-Path -Parent $resolvedPath)) {
    throw 'The rendered review must remain beside its JSON, in the same run directory.'
}
if ([IO.Path]::GetExtension($OutputPath) -ne '.html') {
    throw 'The rendered review is HTML; -OutputPath must end in .html.'
}

$sections = $review.sections
# Each section's dark-cockpit level: only critical findings are red, positives stay unlit.
$levels = [ordered]@{ critical = 'ck-critical'; high = 'ck-high'; improvement = 'ck-notice'; positive = 'ck-ok' }
$counts = [ordered]@{
    critical = @($sections.critical).Count
    high = @($sections.high).Count
    improvement = @($sections.improvements).Count
    positive = @($sections.positives).Count
}
$reference = [Net.WebUtility]::HtmlEncode($review.reference)
$decision = [Net.WebUtility]::HtmlEncode($review.verdict.decision)

$html = [Collections.Generic.List[string]]::new()
$html.Add('<!doctype html>')
$html.Add('<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">')
$html.Add("<title>Code review — $reference</title>")
$html.Add(@'
<style>
:root { --bg: var(--brand-bg); --paper: var(--brand-paper); --ink: var(--brand-ink); --muted: var(--brand-muted);
  --rule: var(--brand-rule); --code: var(--brand-code); }
body { margin: 0; font-size: 16px; line-height: 1.6; }
main { max-width: 880px; margin: 0 auto; padding: 40px 16px 80px; display: grid; gap: 32px; }
h1, h2 { margin: 0; line-height: 1.2; } h1 { font-size: 1.9rem; } h2 { font-size: 1.3rem; }
p { margin: 0; } section { display: grid; gap: 12px; }
code, .loc, .id, .meta { font-family: var(--brand-mono); }
code { font-size: .88em; background: var(--code); padding: .1em .35em; border-radius: 4px; overflow-wrap: anywhere; }
.meta { color: var(--muted); font-size: .85rem; display: flex; flex-wrap: wrap; gap: 4px 18px; }
.verdict, .finding { background: var(--paper); border: 1px solid var(--rule); border-radius: 8px; display: grid; gap: 8px; }
.verdict { padding: 16px 18px; } .finding { padding: 14px 16px; }
.verdict .decision { font-weight: 700; font-size: 1.2rem; color: var(--ck); }
.verdict.ck-ok .decision { font-weight: 400; }
.tally { display: flex; flex-wrap: wrap; gap: 8px; }
.head { display: flex; flex-wrap: wrap; gap: 4px 12px; align-items: baseline; }
.loc { font-size: .8rem; color: var(--muted); overflow-wrap: anywhere; }
.fix { padding-top: 8px; border-top: 1px dashed var(--rule); }
.tag { font-size: .75rem; font-weight: 700; letter-spacing: .06em; text-transform: uppercase; color: var(--muted); }
details.ck-quiet { display: grid; gap: 8px; }
.diagram { overflow-x: auto; background: var(--bg); border: 1px solid var(--rule); border-radius: 6px; padding: 12px; }
.diagram pre { margin: 0; }
</style></head><body><main>
'@)
# A critical finding outranks whatever decision was recorded beside it.
$verdictLevel = if ($counts.critical -gt 0) { 'ck-critical' }
    else {
        switch ($review.verdict.decision) {
            'approve' { 'ck-ok' }
            'approve-with-comments' { 'ck-notice' }
            'pending' { 'ck-info' }
            default { 'ck-high' }
        }
    }
$html.Add("<header><h1>Code review — $reference</h1>")
$html.Add("<div class=""meta""><span>Scope: $([Net.WebUtility]::HtmlEncode($review.scope))</span><span>Review: $([Net.WebUtility]::HtmlEncode($review.reviewId))</span></div></header>")
$html.Add("<div class=""verdict ck-item $verdictLevel""><span class=""tag"">Verdict</span><span class=""decision"">$decision</span>")
$html.Add("<p>$(ConvertTo-ReviewHtml -Value $review.verdict.rationale)</p>")
$html.Add('<div class="tally">')
foreach ($key in $counts.Keys) {
    $chipLevel = if ($counts[$key] -eq 0) { 'ck-ok' } else { $levels[$key] }
    $html.Add("<span class=""ck-badge $chipLevel"">$($counts[$key]) $key</span>")
}
$html.Add('</div></div>')
$html.Add('<section><h2>Summary</h2>')
$html.Add("<p>$(if ($review.summary) { ConvertTo-ReviewHtml -Value $review.summary } else { 'Not set.' })</p></section>")
foreach ($line in Get-FindingSectionHtml -Title 'Critical — must fix before integration' -Level $levels.critical -Notes @($sections.critical)) { $html.Add($line) }
foreach ($line in Get-FindingSectionHtml -Title 'High' -Level $levels.high -Notes @($sections.high)) { $html.Add($line) }
foreach ($line in Get-FindingSectionHtml -Title 'Improvements' -Level $levels.improvement -Notes @($sections.improvements)) { $html.Add($line) }
# Positives are normal state: present for the reader who looks, collapsed so they do not compete.
$html.Add('<section><h2>Positives</h2>')
if (@($sections.positives).Count -eq 0) {
    $html.Add('<p class="ck-quiet">None recorded.</p>')
}
else {
    $html.Add("<details class=""ck-quiet""><summary>$(@($sections.positives).Count) recorded</summary>")
    foreach ($note in @($sections.positives)) {
        $html.Add("<article class=""finding ck-item ck-ok"" id=""$($note.id)""><div class=""head""><span class=""ck-badge ck-ok"">$($note.id)</span></div><p>$(ConvertTo-ReviewHtml -Value $note.text)</p></article>")
    }
    $html.Add('</details>')
}
$html.Add('</section>')
$html.Add('</main></body></html>')

Write-ReviewText -Text ($html -join [Environment]::NewLine) -Path $OutputPath
# Neutral colours come from the report brand, severity colours from the dark-cockpit sheet.
& (Join-Path $PSScriptRoot '../../docs-html-report/scripts/embed-brand.ps1') -Path $OutputPath | Out-Null
& (Join-Path $PSScriptRoot '../../ui-dark-cockpit/scripts/embed-cockpit.ps1') -Path $OutputPath | Out-Null
# Diagrams become inline SVG through the shared HTML report skill's pinned, offline Mermaid build.
& (Join-Path $PSScriptRoot '../../docs-html-report/scripts/render-mermaid.ps1') -Path $OutputPath | Out-Null
Write-Output $OutputPath
