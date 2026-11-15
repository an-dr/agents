#Requires -Version 7
<#
.SYNOPSIS
Renders tmp-agent-progress.html at the repository root from tmp-agent-wip.json.

.DESCRIPTION
The page is derived, never written by hand: it reads tmp-agent-wip.json,
the one state file of every flow, Vibe included, so keeping it current costs
one command and no prose. It always opens with the flow's stage table, the
current stage marked. It reloads itself in the browser and is added to
.git/info/exclude so it never enters history. Without the state file it removes
the page, since a stale page is worse than none.
#>
[CmdletBinding()]
param(
    [string]$RepositoryRoot,
    # an-dr-ai-use-wip-data's folder: the page shows its `workflow` section.
    [Parameter(Mandatory)][string]$WipDataSkill
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $RepositoryRoot) {
    $RepositoryRoot = (git rev-parse --show-toplevel 2>$null)
    if ($LASTEXITCODE -ne 0 -or -not $RepositoryRoot) { throw 'Run inside a git repository or pass -RepositoryRoot.' }
}
$pagePath = Join-Path $RepositoryRoot 'tmp-agent-progress.html'
$wip = Join-Path $WipDataSkill 'scripts/wip.ps1'
$stateJson = (@(& $wip get -Section workflow -Reader an-dr-dev-follow-workflow -Root $RepositoryRoot) -join '')

function ConvertTo-Html([string]$Text) { [Net.WebUtility]::HtmlEncode($Text) }

function Get-ListHtml([string[]]$Items, [string]$Empty = 'none') {
    if (-not $Items -or $Items.Count -eq 0) { return "<p class=`"muted`">$Empty</p>" }
    return '<ul>' + (($Items | ForEach-Object { "<li>$(ConvertTo-Html $_)</li>" }) -join '') + '</ul>'
}

if ($stateJson -eq 'null') {
    Remove-Item -LiteralPath $pagePath -ErrorAction SilentlyContinue
    Write-Output 'No workflow state; tmp-agent-progress.html removed.'
    return
}

$body = [Collections.Generic.List[string]]::new()
$branch = (git -C $RepositoryRoot branch --show-current 2>$null)
$state = $stateJson | ConvertFrom-Json
$flowLabel = switch ($state.flow) { 'SpecDriven' { 'Spec-driven' } 'DetailedAuto' { 'Spec-driven' } 'Detailed' { 'Supervised' } default { $state.flow } }
# What each stage is for, so the table reads without the policy at hand.
$stages = switch ($flowLabel) {
    'Vibe' { [ordered]@{ BUILD = 'The agent builds the change'; VERIFY = 'The agent tests and reviews it'; DELIVER = 'You try it: land, redo, or drop'; LAND = 'Integrated onto the base; tmp files stripped' } }
    'Supervised' { [ordered]@{ INTAKE = 'You close the request list: intake'; DESIGN = 'Options and decisions'; SPLIT = 'You approve the plan: implement'; BRANCH = 'Work branch created'; DOCS = 'Documentation first'; BUILD = 'Code for this increment'; VERIFY = 'You verify the increment'; COMMIT = 'Increment committed'; SUMMARY = 'You review the branch: accept'; HANDOVER = 'Branch handed over, ready to integrate' } }
    default { [ordered]@{ INTAKE = 'Requests gathered in the design talk'; DESIGN = 'Options and decisions'; SPLIT = 'You approve the plan: implement'; BRANCH = 'Work branch created'; DOCS = 'Documentation first'; BUILD = 'Code for each increment'; VERIFY = 'The agent verifies each increment'; COMMIT = 'Increment committed'; SUMMARY = 'Branch summarised'; FINAL_REVIEW = 'You review the branch: accept'; HANDOVER = 'Branch handed over, ready to integrate' } }
}
$names = @($stages.Keys)
$index = [array]::IndexOf($names, [string]$state.phase)
$finished = [bool]($state.PSObject.Properties['finishedAt'] -and $state.finishedAt)
$rows = for ($i = 0; $i -lt $names.Count; $i++) {
    $class, $mark = if ($finished -or $i -lt $index) { 'done', '✔' } elseif ($i -eq $index) { 'now', '▶' } else { 'todo', '' }
    "<tr class=`"$class`"><td>$mark</td><td>$($names[$i])</td><td>$(ConvertTo-Html $stages[$names[$i]])</td></tr>"
}
$title = "$flowLabel · $($state.phase)"
$body.Add("<h1>$(ConvertTo-Html $flowLabel) <span class=`"muted`">·</span> $($state.phase)</h1>")
$body.Add("<p class=`"muted`">Branch $(ConvertTo-Html $branch) → integrates onto <b>$(ConvertTo-Html $state.baseBranch)</b></p>")
$body.Add("<section><h2>Stages</h2><table class=`"stages`"><tr><th></th><th>Stage</th><th>What happens</th></tr>$($rows -join '')</table></section>")

$open = @(@($state.questions).Where({ $_.status -eq 'open' }))
$waiting = if ($finished) { "Handed over: say integrate to land it onto $($state.baseBranch)." }
    elseif ($open.Count -gt 0) { "$($open.Count) open question(s) need your answer." }
    elseif ($state.phase -eq 'INTAKE' -and $flowLabel -eq 'Supervised') { 'Waiting for you to close the request list: intake.' }
    elseif ($state.phase -eq 'SPLIT') { 'Waiting for you to approve the plan: implement.' }
    elseif ($state.phase -eq 'VERIFY' -and $flowLabel -eq 'Supervised') { 'Waiting for you to verify this increment.' }
    elseif ($state.phase -in @('SUMMARY', 'FINAL_REVIEW') -and $flowLabel -ne 'Spec-driven' -or $state.phase -eq 'FINAL_REVIEW') { 'Waiting for your review: accept, or comments.' }
    elseif ($state.phase -eq 'DELIVER') { 'Waiting for you to try it: land, redo, or drop.' }
    else { $null }
if ($waiting) { $body.Add("<p class=`"you`">▶ $(ConvertTo-Html $waiting)</p>") }

$handoff = if ($state.PSObject.Properties['handoff'] -and $state.handoff) { $state.handoff } else { [pscustomobject]@{} }
$field = { param($name) if ($handoff.PSObject.Properties[$name]) { @($handoff.$name) } else { @() } }
$goal = if ($state.requirements.goal) { $state.requirements.goal } elseif (@(& $field 'goal').Count) { @(& $field 'goal') -join ' ' } else { 'not yet defined' }
$goalHtml = "<p>$(ConvertTo-Html $goal)</p>"
if ($state.requirements.done) { $goalHtml += "<p><b>Done when:</b> $(ConvertTo-Html $state.requirements.done)</p>" }
$body.Add("<section><h2>Goal</h2>$goalHtml</section>")

$increments = @($state.increments)
if ($increments.Count -gt 0) {
    $incRows = $increments | ForEach-Object {
        $mark = switch ($_.status) { 'completed' { '✔' } 'planned' { '·' } default { '▶' } }
        "<tr class=`"$($_.status)`"><td>$mark</td><td>$($_.number)</td><td>$(ConvertTo-Html $_.scope)</td><td>$(ConvertTo-Html $_.description)</td></tr>"
    }
    $body.Add("<section><h2>Increments</h2><div class=`"scroll`"><table>$($incRows -join '')</table></div></section>")
}

$questions = @($state.questions)
if ($questions.Count -gt 0) {
    $items = @($open | ForEach-Object { "<li class=`"open`"><b>?</b> $(ConvertTo-Html $_.text)</li>" }) +
        @(@($questions).Where({ $_.status -ne 'open' }) | ForEach-Object { "<li class=`"closed`">$(ConvertTo-Html $_.text) → $(ConvertTo-Html $_.answer)</li>" })
    $body.Add("<section><h2>Questions</h2><ul>$($items -join '')</ul></section>")
}

foreach ($pair in @(@('next', 'Next'), @('done', 'Done'), @('openQuestions', 'Open questions'), @('decisions', 'Decisions and why'), @('files', 'Files in play'))) {
    $items = @(& $field $pair[0])
    if ($items.Count) { $body.Add("<section><h2>$($pair[1])</h2>$(Get-ListHtml -Items $items)</section>") }
}

$recent = @(@($state.history) | Select-Object -Last 8)
[array]::Reverse($recent)
$log = $recent | ForEach-Object { "<li><span class=`"muted`">$(([datetime]$_.at).ToLocalTime().ToString('HH:mm'))</span> $(ConvertTo-Html $_.detail)</li>" }
$body.Add("<section><h2>Recent steps</h2><ul class=`"log`">$($log -join '')</ul></section>")

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
.stages th { text-align: left; font-size: .8rem; opacity: .7; padding: .3rem .5rem; } .stages td:first-child { width: 1.5rem; }
.stages .done { opacity: .5; } .stages .now td { color: var(--accent); font-weight: 700; }
.you { border-left: 4px solid var(--accent); padding: .4rem .8rem; font-weight: 600; }
table { border-collapse: collapse; width: 100%; } td { border-bottom: 1px solid var(--line); padding: .3rem .5rem; vertical-align: top; }
tr.completed { opacity: .6; } tr.in_progress td, tr.verified td { font-weight: 600; }
li.open { color: var(--accent); } li.closed { opacity: .7; } .log { list-style: none; padding: 0; }
</style></head>
<body><main>
$($body -join "`n")
<p class="muted">Rendered $stamp · reloads every 5 s</p>
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
