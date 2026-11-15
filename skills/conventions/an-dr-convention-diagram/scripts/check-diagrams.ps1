#Requires -Version 7
<#
.SYNOPSIS
Measures Mermaid diagrams against the an-dr-convention-diagram budget.

.DESCRIPTION
Reads fenced `mermaid` blocks in Markdown and `<pre class="mermaid">` blocks in
HTML. For flowchart, graph, and stateDiagram blocks it counts nodes, labelled
edges, nesting, edges back to earlier steps, label length, and the length of a
left-to-right run, and reports every block over budget. Other diagram types are
listed as not measured. A block with a `%% diagram-budget: exempt <reason>`
line is skipped. Exits 1 when any block is over budget.

.EXAMPLE
pwsh check-diagrams.ps1 -Path README.md, docs
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string[]]$Path,
    [int]$MaxItems = 7,
    [int]$MaxLoops = 1,
    [int]$MaxLabelWords = 2,
    [int]$MaxRowNodes = 4
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DiagramFile {
    param([string[]]$Paths)
    foreach ($item in $Paths) {
        if (-not (Test-Path -LiteralPath $item)) { throw "Path not found: $item" }
        if (Test-Path -LiteralPath $item -PathType Container) {
            Get-ChildItem -LiteralPath $item -Recurse -File -Include '*.md', '*.html' |
                Where-Object { $_.FullName -notmatch '[\\/](\.git|node_modules)[\\/]' }
        }
        else { Get-Item -LiteralPath $item }
    }
}

function Get-MermaidBlock {
    <# Returns @{ Line; Source } for each Mermaid block in the text. #>
    param([string]$Text, [string]$Extension)
    $blocks = @()
    if ($Extension -eq '.html') {
        foreach ($m in [regex]::Matches($Text, '<pre class="mermaid"[^>]*>(.*?)</pre>', 'Singleline')) {
            $source = [Net.WebUtility]::HtmlDecode($m.Groups[1].Value)
            $blocks += @{ Line = ($Text.Substring(0, $m.Index) -split "`n").Count; Source = $source }
        }
        return $blocks
    }
    $lines = $Text -split "`r?`n"
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($start -lt 0 -and $lines[$i] -match '^\s*(```|~~~)\s*mermaid\s*$') { $start = $i; continue }
        if ($start -ge 0 -and $lines[$i] -match '^\s*(```|~~~)\s*$') {
            $blocks += @{ Line = $start + 1; Source = ($lines[($start + 1)..($i - 1)] -join "`n") }
            $start = -1
        }
    }
    return $blocks
}

function Measure-Diagram {
    <# Returns the counts for one flowchart or state diagram, or $null for other types. #>
    param([string]$Source)

    $all = @($Source -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $exempt = @($all | Where-Object { $_ -match '^%%\s*diagram-budget:\s*exempt(\s|$)' })
    $lines = @($all | Where-Object { -not $_.StartsWith('%%') })
    if ($lines.Count -eq 0) { return $null }
    if ($exempt.Count -gt 0) { return 'exempt' }
    $header = $lines[0]
    $isState = $header -match '^stateDiagram'
    if (-not $isState -and $header -notmatch '^(flowchart|graph)\b') { return $null }

    $direction = if ($header -match '\b(LR|RL)\b') { 'LR' } elseif ($isState) { 'TB' } else { 'TB' }
    $order = [Collections.Generic.List[string]]::new()
    $edges = [Collections.Generic.List[object]]::new()
    $depth = 0
    $maxDepth = 0
    $longLabels = [Collections.Generic.List[string]]::new()
    # Decision nodes ({...}); a one-word outcome leaving one belongs to the decision.
    $decisions = [Collections.Generic.HashSet[string]]::new()

    $addNode = {
        param([string]$Id)
        if ($Id -and $Id -ne '[*]' -and -not $order.Contains($Id)) { $order.Add($Id) }
    }

    foreach ($line in $lines | Select-Object -Skip 1) {
        if ($line -match '^direction\s+(LR|RL|TB|TD|BT)') {
            if ($depth -eq 0) { $direction = if ($Matches[1] -in 'LR', 'RL') { 'LR' } else { 'TB' } }
            continue
        }
        if ($line -match '^(classDef|class|style|linkStyle|click|note)\b') { continue }
        if ($line -match '^subgraph\b' -or ($isState -and $line -match '^state\s+.*\{\s*$')) {
            $depth++; $maxDepth = [Math]::Max($maxDepth, $depth); continue
        }
        if ($line -eq 'end' -or $line -eq '}') { $depth = [Math]::Max(0, $depth - 1); continue }

        # An edge: id [shape] arrow [|label|] id [shape] [: label]
        $edgePattern = '^(?<from>\[\*\]|[\w.-]+)(?:\s*(?<fshape>[\[\(\{>])[^\n]*?[\]\)\}]+)?\s*(?<arrow>--?>|==+>|-\.->|---|--\s[^-]+-->|-->)\s*(?:\|(?<pipe>[^|]*)\|)?\s*(?<to>\[\*\]|[\w.-]+)(?:\s*(?<tshape>[\[\(\{>])[^\n]*?[\]\)\}]+)?\s*(?::\s*(?<colon>.+))?$'
        $m = [regex]::Match($line, $edgePattern)
        if ($m.Success) {
            $label = $null
            if ($m.Groups['pipe'].Success) { $label = $m.Groups['pipe'].Value }
            elseif ($m.Groups['colon'].Success) { $label = $m.Groups['colon'].Value }
            elseif ($m.Groups['arrow'].Value -match '^--\s(.+)-->$') { $label = $Matches[1] }
            $label = if ($label) { ($label -replace '"', '').Trim() } else { $null }
            & $addNode $m.Groups['from'].Value
            & $addNode $m.Groups['to'].Value
            if ($m.Groups['fshape'].Value -eq '{') { [void]$decisions.Add($m.Groups['from'].Value) }
            if ($m.Groups['tshape'].Value -eq '{') { [void]$decisions.Add($m.Groups['to'].Value) }
            $edges.Add([pscustomobject]@{ From = $m.Groups['from'].Value; To = $m.Groups['to'].Value; Label = $label })
            if ($label -and @($label -split '\s+').Count -gt $MaxLabelWords) { $longLabels.Add($label) }
            continue
        }
        # A node declaration on its own line.
        if ($line -match '^(?<id>[\w.-]+)\s*(?<shape>[\[\(\{>])') {
            & $addNode $Matches['id']
            if ($Matches['shape'] -eq '{') { [void]$decisions.Add($Matches['id']) }
            continue
        }
        if ($isState -and $line -match '^state\s+"[^"]*"\s+as\s+(?<id>[\w.-]+)') { & $addNode $Matches['id']; continue }
        if ($isState -and $line -match '^(?<id>[\w.-]+)\s*:') { & $addNode $Matches['id']; continue }
    }

    # An edge back: its target was first seen before its source.
    $loops = @($edges | Where-Object {
            $_.From -ne '[*]' -and $_.To -ne '[*]' -and $order.IndexOf($_.To) -le $order.IndexOf($_.From)
        }).Count
    $labelled = @($edges | Where-Object {
            $_.Label -and $_.From -ne '[*]' -and $_.To -ne '[*]' -and
            -not ($decisions.Contains($_.From) -and @($_.Label -split '\s+').Count -eq 1)
        }).Count
    return [pscustomobject]@{
        Nodes      = $order.Count
        Labelled   = $labelled
        Items      = $order.Count + $labelled
        Levels     = 1 + $maxDepth
        Loops      = $loops
        Direction  = $direction
        LongLabels = @($longLabels)
    }
}

$over = 0
$measured = 0
$unmeasured = 0
$exempted = 0
foreach ($file in Get-DiagramFile -Paths $Path) {
    $text = [IO.File]::ReadAllText($file.FullName)
    foreach ($block in Get-MermaidBlock -Text $text -Extension $file.Extension.ToLowerInvariant()) {
        $result = Measure-Diagram -Source $block.Source
        if (-not $result) { $unmeasured++; continue }
        if ($result -eq 'exempt') { $exempted++; continue }
        $measured++
        $problems = @()
        if ($result.Items -gt $MaxItems) { $problems += "items $($result.Items) > $MaxItems ($($result.Nodes) nodes, $($result.Labelled) labelled edges)" }
        if ($result.Levels -gt 1) { $problems += "levels $($result.Levels) > 1 (a group has its own inside; make it a black box)" }
        if ($result.Loops -gt $MaxLoops) { $problems += "loops $($result.Loops) > $MaxLoops" }
        if ($result.Direction -eq 'LR' -and $result.Nodes -gt $MaxRowNodes) { $problems += "left-to-right with $($result.Nodes) nodes > $MaxRowNodes" }
        foreach ($label in $result.LongLabels) { $problems += "label '$label' is over $MaxLabelWords words" }
        if ($problems.Count -gt 0) {
            $over++
            Write-Output "$($file.FullName):$($block.Line)"
            $problems | ForEach-Object { Write-Output "  over    $_" }
        }
    }
}

Write-Output ''
Write-Output "$measured diagram(s) measured, $over over budget, $exempted exempt, $unmeasured of other types not measured."
if ($over -gt 0) { exit 1 }
