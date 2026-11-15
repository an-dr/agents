#Requires -Version 7
<# Regression cases for check-diagrams.ps1: budget limits, decision outcomes, exemption, file types. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$checker = Join-Path $PSScriptRoot '..' 'check-diagrams.ps1'
$dir = Join-Path ([IO.Path]::GetTempPath()) ('an-dr-diagram-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir | Out-Null
$fence = '```'
function New-Case([string]$Name, [string[]]$Body, [int]$Exit, [string]$Expect = '', [string]$Ext = '.md') {
    @{ Name = $Name; Body = ($Body -join "`n"); Exit = $Exit; Expect = $Expect; Ext = $Ext }
}
$cases = @(
    New-Case 'small-flow' @('flowchart TD', 'A[Start] --> B[Do]', 'B --> C[End]') 0
    New-Case 'decision-outcomes-free' @('flowchart TD', 'S([Task]) --> A{Design first?}', 'A -- no --> V[Vibe]', 'A -- yes --> C{Each increment?}', 'C -- no --> D[Spec]', 'C -- yes --> E[Supervised]') 0
    New-Case 'too-many-items' @('flowchart TD', 'A --> B', 'B --> C', 'C --> D', 'D --> E', 'E --> F', 'F --> G', 'G --> H') 1 'items 8 > 7'
    New-Case 'nested-group' @('stateDiagram-v2', '[*] --> A', 'state A {', '  B --> C', '}') 1 'levels 2 > 1'
    New-Case 'two-loops' @('stateDiagram-v2', 'A --> B', 'B --> A', 'B --> C', 'C --> A') 1 'loops 2 > 1'
    New-Case 'long-label' @('flowchart TD', 'A -->|draft PR marked ready| B') 1 "label 'draft PR marked ready'"
    New-Case 'long-row' @('flowchart LR', 'A --> B', 'B --> C', 'C --> D', 'D --> E') 1 'left-to-right with 5 nodes'
    New-Case 'exempt' @('flowchart LR', '%% diagram-budget: exempt generated graph', 'A --> B --> C --> D --> E --> F --> G --> H') 0 '1 exempt'
    New-Case 'other-type' @('sequenceDiagram', 'A->>B: hi') 0 '1 of other types not measured'
)
$failures = @()
foreach ($case in $cases) {
    $file = Join-Path $dir ($case.Name + $case.Ext)
    [IO.File]::WriteAllText($file, "# Case`n`n$fence" + "mermaid`n$($case.Body)`n$fence`n")
    $output = (& pwsh -NoProfile -File $checker -Path $file 2>&1) -join "`n"
    if ($LASTEXITCODE -ne $case.Exit) { $failures += "$($case.Name): exit $LASTEXITCODE, expected $($case.Exit)`n$output" }
    elseif ($case.Expect -and -not $output.Contains($case.Expect)) { $failures += "$($case.Name): output lacks '$($case.Expect)'`n$output" }
}
# HTML blocks are read with entities decoded.
$html = Join-Path $dir 'page.html'
[IO.File]::WriteAllText($html, '<pre class="mermaid">flowchart LR' + "`n" + 'A --&gt; B' + "`n" + 'B --&gt; C' + "`n" + 'C --&gt; D' + "`n" + 'D --&gt; E</pre>')
$output = (& pwsh -NoProfile -File $checker -Path $html 2>&1) -join "`n"
if ($LASTEXITCODE -ne 1 -or -not $output.Contains('left-to-right with 5 nodes')) { $failures += "html: $output" }
Remove-Item -Recurse -Force $dir
if ($failures.Count -gt 0) { $failures | ForEach-Object { Write-Output "FAIL: $_" }; exit 1 }
Write-Output "Diagram checks passed ($($cases.Count + 1) cases)."
