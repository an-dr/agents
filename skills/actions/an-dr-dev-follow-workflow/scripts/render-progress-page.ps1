#Requires -Version 7
<#
.SYNOPSIS
Renders tmp-agent-progress.html at the repository root from .progress state.

.DESCRIPTION
The page is derived, never written by hand: it reads .progress/workflow.json
when a gated flow is active and .progress/handoff.md in any flow, so keeping it
current costs one command and no prose. It reloads itself in the browser and is
added to .git/info/exclude so it never enters history. Without either source
file it removes the page, since a stale page is worse than none.
#>
[CmdletBinding()]
param([string]$RepositoryRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $RepositoryRoot) {
    $RepositoryRoot = (git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $RepositoryRoot) { throw 'Run inside a git repository or pass -RepositoryRoot.' }
}
$pagePath = Join-Path $RepositoryRoot 'tmp-agent-progress.html'
$workflowPath = Join-Path $RepositoryRoot '.progress/workflow.json'
$handoffPath = Join-Path $RepositoryRoot '.progress/handoff.md'

function ConvertTo-Html([string]$Text) { [Net.WebUtility]::HtmlEncode($Text) }

function ConvertFrom-HandoffSection {
    # handoff.md is a fixed set of "## Heading" sections; each becomes a list.
    param([string]$Markdown)
    $sections = [ordered]@{}
    $current = $null
    foreach ($line in ($Markdown -split "`r?`n")) {
        if ($line -match '^#{1,3}\s+(.+?)\s*$') { $current = $Matches[1]; $sections[$current] = [Collections.Generic.List[string]]::new(); continue }
        if ($current -and $line.Trim()) { $sections[$current].Add(($line -replace '^\s*[-*]\s+', '').Trim()) }
    }
    return $sections
}

function Get-ListHtml([string[]]$Items, [string]$Empty = 'none') {
    if (-not $Items -or $Items.Count -eq 0) { return "<p class=`"muted`">$Empty</p>" }
    return '<ul>' + (($Items | ForEach-Object { "<li>$(ConvertTo-Html $_)</li>" }) -join '') + '</ul>'
}

$hasWorkflow = Test-Path -LiteralPath $workflowPath
$hasHandoff = Test-Path -LiteralPath $handoffPath
if (-not $hasWorkflow -and -not $hasHandoff) {
    Remove-Item -LiteralPath $pagePath -ErrorAction SilentlyContinue
    Write-Output 'No progress state; tmp-agent-progress.html removed.'
    return
}

$body = [Collections.Generic.List[string]]::new()
$title = 'Agent progress'
$branch = (git -C $RepositoryRoot branch --show-current 2>$null)

if ($hasWorkflow) {
    $state = Get-Content -Raw -LiteralPath $workflowPath | ConvertFrom-Json
    $flowLabel = switch ($state.flow) { 'SpecDriven' { 'Spec-driven' } 'DetailedAuto' { 'Spec-driven' } 'Detailed' { 'Supervised' } default { $state.flow } }
    $phases = if ($flowLabel -eq 'Supervised') {
        @('INTAKE', 'DESIGN', 'SPLIT', 'BRANCH', 'DOCS', 'BUILD', 'VERIFY', 'COMMIT', 'SUMMARY', 'INTEGRATE')
    } else {
        @('INTAKE', 'DESIGN', 'SPLIT', 'BRANCH', 'DOCS', 'BUILD', 'VERIFY', 'COMMIT', 'SUMMARY', 'FINAL_REVIEW', 'INTEGRATE')
    }
    $index = [array]::IndexOf($phases, [string]$state.phase)
    $steps = for ($i = 0; $i -lt $phases.Count; $i++) {
        $class = if ($i -lt $index) { 'done' } elseif ($i -eq $index) { 'now' } else { 'todo' }
        "<li class=`"$class`">$($phases[$i])</li>"
    }
    $title = "$flowLabel · $($state.phase)"
    $body.Add("<h1>$(ConvertTo-Html $flowLabel) <span class=`"muted`">·</span> $($state.phase)</h1>")
    $body.Add("<ol class=`"phases`">$($steps -join '')</ol>")

    $open = @(@($state.questions).Where({ $_.status -eq 'open' }))
    $waiting = if ($open.Count -gt 0) { "$($open.Count) open question(s) need your answer." }
        elseif ($state.phase -eq 'INTAKE' -and $flowLabel -eq 'Supervised') { 'Waiting for you to close the request list: intake.' }
        elseif ($state.phase -eq 'SPLIT') { 'Waiting for you to approve the plan: implement.' }
        elseif ($state.phase -eq 'VERIFY' -and $flowLabel -eq 'Supervised') { 'Waiting for you to verify this increment.' }
        elseif ($state.phase -in @('SUMMARY', 'FINAL_REVIEW')) { 'Waiting for your review: integrate, or comments.' }
        else { $null }
    if ($waiting) { $body.Add("<p class=`"you`">▶ $(ConvertTo-Html $waiting)</p>") }

    $goal = if ($state.requirements.goal) { $state.requirements.goal } else { 'not yet defined' }
    $done = if ($state.requirements.done) { $state.requirements.done } else { 'not yet defined' }
    $body.Add("<section><h2>Goal</h2><p>$(ConvertTo-Html $goal)</p><p><b>Done when:</b> $(ConvertTo-Html $done)</p></section>")

    $increments = @($state.increments)
    if ($increments.Count -gt 0) {
        $rows = $increments | ForEach-Object {
            $mark = switch ($_.status) { 'completed' { '✔' } 'planned' { '·' } default { '▶' } }
            "<tr class=`"$($_.status)`"><td>$mark</td><td>$($_.number)</td><td>$(ConvertTo-Html $_.scope)</td><td>$(ConvertTo-Html $_.description)</td></tr>"
        }
        $body.Add("<section><h2>Increments</h2><div class=`"scroll`"><table>$($rows -join '')</table></div></section>")
    }

    $questions = @($state.questions)
    if ($questions.Count -gt 0) {
        $items = @($open | ForEach-Object { "<li class=`"open`"><b>?</b> $(ConvertTo-Html $_.text)</li>" }) +
            @(@($questions).Where({ $_.status -ne 'open' }) | ForEach-Object { "<li class=`"closed`">$(ConvertTo-Html $_.text) → $(ConvertTo-Html $_.answer)</li>" })
        $body.Add("<section><h2>Questions</h2><ul>$($items -join '')</ul></section>")
    }
}
else {
    $body.Add('<h1>Vibe <span class="muted">· no gates</span></h1>')
}

if ($hasHandoff) {
    $handoff = ConvertFrom-HandoffSection -Markdown (Get-Content -Raw -LiteralPath $handoffPath)
    foreach ($name in @('Next', 'Done', 'Open questions', 'Decisions and why')) {
        if ($handoff.Contains($name)) {
            $body.Add("<section><h2>$name</h2>$(Get-ListHtml -Items $handoff[$name])</section>")
        }
    }
}

if ($hasWorkflow) {
    $recent = @(@($state.history) | Select-Object -Last 8)
    [array]::Reverse($recent)
    $items = $recent | ForEach-Object { "<li><span class=`"muted`">$(([datetime]$_.at).ToLocalTime().ToString('HH:mm'))</span> $(ConvertTo-Html $_.detail)</li>" }
    $body.Add("<section><h2>Recent steps</h2><ul class=`"log`">$($items -join '')</ul></section>")
}

$stamp = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
$html = @"
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="5"><title>$(ConvertTo-Html $title)</title>
<style>
:root { color-scheme: light dark; --accent: #c2185b; --ok: #2e7d32; --line: color-mix(in srgb, currentColor 20%, transparent); }
body { font: 15px/1.5 system-ui, sans-serif; margin: 0; }
main { max-width: 56rem; margin: 0 auto; padding: 1rem 1.25rem 3rem; }
h1 { margin: .2rem 0 .6rem; } h2 { font-size: 1rem; margin: 1.4rem 0 .3rem; text-transform: uppercase; letter-spacing: .05em; opacity: .8; }
.muted { opacity: .6; } .scroll { overflow-x: auto; }
.phases { display: flex; flex-wrap: wrap; gap: .3rem; list-style: none; padding: 0; margin: 0; }
.phases li { padding: .15rem .5rem; border: 1px solid var(--line); border-radius: 1rem; font-size: .8rem; }
.phases .done { opacity: .5; text-decoration: line-through; } .phases .now { border-color: var(--accent); color: var(--accent); font-weight: 700; }
.you { border-left: 4px solid var(--accent); padding: .4rem .8rem; font-weight: 600; }
table { border-collapse: collapse; width: 100%; } td { border-bottom: 1px solid var(--line); padding: .3rem .5rem; vertical-align: top; }
tr.completed { opacity: .6; } tr.in_progress td, tr.verified td { font-weight: 600; }
li.open { color: var(--accent); } li.closed { opacity: .7; } .log { list-style: none; padding: 0; }
</style></head>
<body><main>
$($body -join "`n")
<p class="muted">Branch $(ConvertTo-Html $branch) · rendered $stamp · reloads every 5 s</p>
</main></body></html>
"@
[IO.File]::WriteAllText($pagePath, $html, [Text.UTF8Encoding]::new($false))

# Keep the page out of history without touching the host's .gitignore.
$excludePath = Join-Path (git -C $RepositoryRoot rev-parse --git-path info/exclude) ''
if (-not [IO.Path]::IsPathRooted($excludePath)) { $excludePath = Join-Path $RepositoryRoot $excludePath }
$excludePath = $excludePath.TrimEnd('\', '/')
if (-not (Test-Path -LiteralPath $excludePath) -or -not (Select-String -LiteralPath $excludePath -SimpleMatch '/tmp-agent-progress.html' -Quiet)) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $excludePath) | Out-Null
    Add-Content -LiteralPath $excludePath -Value '/tmp-agent-progress.html'
}
Write-Output "Rendered $pagePath"
