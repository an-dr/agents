#Requires -Version 7
<#
.SYNOPSIS
Reads a user's reply against a questions file and writes the decisions as answers JSON.

.DESCRIPTION
Accepts every reply form an-dr-ai-send-message allows: `1a 2bc`, `1a, 2b`, `a b` in question order, `1: a`, `Q2 b`,
an option label, `y`/`n` for a confirmation, or free text after `N:`. Pass a native widget's chosen
labels the same way, as `1: <label>`. Prints one echo line per question and writes the JSON file.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $Questions,
    [Parameter(Mandatory)] [AllowEmptyString()] [string] $Reply,
    [string] $Out
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$spec = Get-Content -LiteralPath $Questions -Raw | ConvertFrom-Json
$list = @($spec.questions)
if (-not $list.Count) { throw "No questions in $Questions." }
foreach ($q in $list) {
    if (-not $q.id -or @($q.options).Count -lt 2) { throw "Question '$($q.id)' needs an id and at least 2 options." }
}
if (-not $Out) { $Out = Join-Path (Split-Path -Parent (Resolve-Path $Questions)) 'answers.json' }

function Get-PlainLabel([string] $label) {
    ($label -replace '\s*\(Recommended\)\s*$', '').Trim().ToLowerInvariant()
}

# Split the reply into one segment per question number; a reply without numbers is positional.
$segments = @{}
$markers = [regex]::Matches($Reply, '(?i)(?:^|(?<=[\s,;]))q?(\d+)\s*[:.)]?\s*')
$markers = @($markers | Where-Object { [int]$_.Groups[1].Value -ge 1 -and [int]$_.Groups[1].Value -le $list.Count })
if ($markers.Count) {
    for ($i = 0; $i -lt $markers.Count; $i++) {
        $start = $markers[$i].Index + $markers[$i].Length
        $end = if ($i + 1 -lt $markers.Count) { $markers[$i + 1].Index } else { $Reply.Length }
        $segments[[int]$markers[$i].Groups[1].Value] = $Reply.Substring($start, $end - $start).Trim(" `t`r`n,;".ToCharArray())
    }
}
elseif ($list.Count -eq 1) {
    if ($Reply.Trim()) { $segments[1] = $Reply.Trim() }
}
else {
    $tokens = @($Reply -split '[\s,;]+' | Where-Object { $_ })
    if ($tokens.Count -and @($tokens | Where-Object { $_ -notmatch '^[a-zA-Z]+$' }).Count -eq 0) {
        for ($i = 0; $i -lt [Math]::Min($tokens.Count, $list.Count); $i++) { $segments[$i + 1] = $tokens[$i] }
    }
    elseif ($Reply.Trim()) { throw 'A reply to several questions needs question numbers, like `1a 2b` or `2: text`.' }
}

$answers = @()
$echo = @()
for ($n = 1; $n -le $list.Count; $n++) {
    $q = $list[$n - 1]
    $options = @($q.options)
    $keys = for ($k = 0; $k -lt $options.Count; $k++) { if ($options[$k].key) { "$($options[$k].key)".ToLowerInvariant() } else { [string][char](97 + $k) } }
    $answer = [ordered]@{ id = $q.id; status = 'open'; choices = @(); labels = @(); text = $null }
    $raw = $segments[$n]
    if ($raw) {
        $value = Get-PlainLabel $raw
        $picked = @()
        if ($q.kind -eq 'confirm' -and $value -match '^(y|yes|n|no)$') {
            $word = if ($value.StartsWith('y')) { 'yes' } else { 'no' }
            $picked = @(for ($k = 0; $k -lt $options.Count; $k++) { if ((Get-PlainLabel $options[$k].label).StartsWith($word)) { $k } })
        }
        elseif ($value -match '^[a-z]+$' -and @($value.ToCharArray() | Where-Object { $keys -notcontains "$_" }).Count -eq 0) {
            $picked = @($value.ToCharArray() | Select-Object -Unique | ForEach-Object { [array]::IndexOf($keys, "$_") })
        }
        else {
            $exact = @(for ($k = 0; $k -lt $options.Count; $k++) { if ((Get-PlainLabel $options[$k].label) -eq $value) { $k } })
            $prefix = @(for ($k = 0; $k -lt $options.Count; $k++) { if ($value.Length -ge 3 -and (Get-PlainLabel $options[$k].label).StartsWith($value)) { $k } })
            $picked = if ($exact.Count) { $exact } elseif ($prefix.Count -eq 1) { $prefix } else { @() }
            if (-not $picked.Count -and $prefix.Count -gt 1) { $answer.status = 'ambiguous'; $answer.text = $raw }
        }

        if ($picked.Count -gt 1 -and -not $q.multiSelect) { $answer.status = 'ambiguous'; $answer.text = $raw }
        elseif ($picked.Count) {
            $answer.status = 'answered'
            $answer.choices = @($picked | ForEach-Object { $keys[$_] })
            $answer.labels = @($picked | ForEach-Object { $options[$_].label })
        }
        elseif ($answer.status -ne 'ambiguous') { $answer.status = 'custom'; $answer.text = $raw }
    }
    $answers += [pscustomobject]$answer
    $echo += switch ($answer.status) {
        'answered' { "$($q.id) → " + ((0..($answer.choices.Count - 1) | ForEach-Object { "$($answer.choices[$_]). $($answer.labels[$_])" }) -join '; ') }
        'custom' { "$($q.id) → custom: $($answer.text)" }
        'ambiguous' { "$($q.id) → ambiguous: $($answer.text) (ask again)" }
        default { "$($q.id) → open" }
    }
}

[ordered]@{ questions = (Resolve-Path $Questions).Path; reply = $Reply; answers = $answers } |
    ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Out -Encoding utf8
$echo
