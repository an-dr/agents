#Requires -Version 7
<# Runs the controller through each flow's gates in a throwaway repository. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$controller = Join-Path $PSScriptRoot '..' 'workflow.ps1'
$failures = [Collections.Generic.List[string]]::new()

function Invoke-Workflow {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    $output = @(& pwsh -NoProfile -NonInteractive -File $controller @Arguments 2>&1)
    return [pscustomobject]@{ Code = $LASTEXITCODE; Output = ($output -join "`n") }
}

function Assert-Pass {
    param([string]$Name, [string[]]$Arguments)
    $result = Invoke-Workflow @Arguments
    if ($result.Code -ne 0) { $failures.Add("$Name failed: $($result.Output)") }
}

function Assert-Fail {
    param([string]$Name, [string[]]$Arguments, [string]$Pattern)
    $result = Invoke-Workflow @Arguments
    if ($result.Code -eq 0) { $failures.Add("$Name should have failed.") }
    elseif ($result.Output -notmatch $Pattern) { $failures.Add("$Name failed for the wrong reason: $($result.Output)") }
}

function New-Repository {
    $path = Join-Path ([IO.Path]::GetTempPath()) ("wf-test-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $path | Out-Null
    Push-Location $path
    git init -q -b main
    git config user.email 'test@example.invalid'
    git config user.name 'Test'
    Add-Content -Path '.git/info/exclude' -Value '.progress/'
    Set-Content -Path 'README.md' -Value 'test'
    git add README.md
    git commit -q -m 'chore: initial'
    return $path
}

function Close-Repository {
    param([string]$Path)
    Pop-Location
    Remove-Item -Recurse -Force -LiteralPath $Path
}

function Set-Intake {
    Assert-Pass 'add-request' @('add-request', '-Text', 'Make X')
    foreach ($field in @('goal', 'constraints', 'done', 'outOfScope')) {
        Assert-Pass "set $field" @('set-requirement', '-Field', $field, '-Value', "$field text")
    }
}

function Complete-Increment {
    param([string]$File)
    Assert-Pass 'docs->build' @('advance')
    Assert-Pass 'build->verify' @('advance')
}

# Spec-driven: no intake gate, implement at SPLIT, agent-verified increments,
# integrate at FINAL_REVIEW.
$repo = New-Repository
try {
    Assert-Pass 'spec start' @('start', '-Flow', 'SpecDriven')
    if (-not (Test-Path 'tmp-agent-progress.html')) { $failures.Add('Progress page was not rendered at start.') }
    if (@(git status --porcelain -- tmp-agent-progress.html).Count -gt 0) { $failures.Add('Progress page is not excluded from git.') }
    Set-Intake
    Assert-Fail 'spec refuses intake gate' @('approve', '-Gate', 'intake', '-Note', 'x') 'records its own intake'
    Assert-Pass 'spec intake->design' @('advance')
    Assert-Pass 'spec design->split' @('advance')
    Assert-Pass 'spec add increment' @('add-increment', '-Scope', 'core', '-Description', 'does X')
    Assert-Fail 'spec split needs implement' @('advance') 'implement'
    Assert-Pass 'spec implement' @('approve', '-Gate', 'implement', '-Note', 'implement')
    Assert-Pass 'spec split->branch' @('advance')
    Assert-Fail 'spec branch refuses base' @('advance') 'feature branch'
    git switch -q -c spec/x
    Assert-Pass 'spec branch->docs' @('advance')
    Complete-Increment
    Assert-Fail 'spec refuses verify gate' @('approve', '-Gate', 'verify', '-Note', 'x') 'records its own'
    Assert-Pass 'spec verify->commit' @('advance')
    Set-Content -Path 'x.txt' -Value 'x'
    git add x.txt
    git commit -q -m 'feat: x'
    Assert-Pass 'spec commit->summary' @('advance')
    Assert-Pass 'spec summary->final review' @('advance')
    Assert-Fail 'spec final review needs integrate' @('advance') 'integrate'
    Assert-Pass 'spec integrate' @('approve', '-Gate', 'integrate', '-Note', 'integrate')
    Assert-Pass 'spec final review->integrate' @('advance')
    Assert-Pass 'spec finish' @('finish')
    if (Test-Path 'tmp-agent-progress.html') { $failures.Add('Progress page survived finish.') }
}
finally { Close-Repository $repo }

# Spec-driven on the base branch when the user asks for it.
$repo = New-Repository
try {
    Assert-Pass 'onbase start' @('start', '-Flow', 'SpecDriven', '-OnBase')
    Set-Intake
    Assert-Pass 'onbase intake->design' @('advance')
    Assert-Pass 'onbase design->split' @('advance')
    Assert-Pass 'onbase add increment' @('add-increment', '-Scope', 'core', '-Description', 'does X')
    Assert-Pass 'onbase implement' @('approve', '-Gate', 'implement', '-Note', 'implement')
    Assert-Pass 'onbase split->branch' @('advance')
    Assert-Pass 'onbase stays on main' @('advance')
}
finally { Close-Repository $repo }

# Supervised keeps every gate and never runs on the base branch.
$repo = New-Repository
try {
    Assert-Fail 'supervised refuses onbase' @('start', '-Flow', 'Supervised', '-OnBase') 'only available for SpecDriven'
    Assert-Pass 'supervised start' @('start', '-Flow', 'Supervised')
    Set-Intake
    Assert-Fail 'supervised intake needs gate' @('advance') 'intake'
    Assert-Pass 'supervised intake' @('approve', '-Gate', 'intake', '-Note', 'intake')
    Assert-Pass 'supervised intake->design' @('advance')
    Assert-Pass 'supervised design->split' @('advance')
    Assert-Pass 'supervised add increment' @('add-increment', '-Scope', 'core', '-Description', 'does X')
    Assert-Pass 'supervised implement' @('approve', '-Gate', 'implement', '-Note', 'implement')
    Assert-Pass 'supervised split->branch' @('advance')
    git switch -q -c supervised/x
    Assert-Pass 'supervised branch->docs' @('advance')
    Complete-Increment
    Assert-Fail 'supervised verify needs gate' @('advance') 'verify'
}
finally { Close-Repository $repo }

# Retired flows: Detailed Auto resumes as Spec-driven, Quick is refused.
$repo = New-Repository
try {
    Assert-Pass 'legacy start' @('start', '-Flow', 'SpecDriven')
    $path = '.progress/workflow.json'
    $state = Get-Content -Raw $path | ConvertFrom-Json
    $state.flow = 'DetailedAuto'
    $state | ConvertTo-Json -Depth 10 | Set-Content $path
    $result = Invoke-Workflow 'status'
    if ($result.Code -ne 0 -or $result.Output -notmatch 'Spec-driven') { $failures.Add("DetailedAuto did not resume as Spec-driven: $($result.Output)") }
    $state.flow = 'Quick'
    $state | ConvertTo-Json -Depth 10 | Set-Content $path
    Assert-Fail 'quick refused' @('status') 'retired Quick flow'
}
finally { Close-Repository $repo }

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Output "FAIL: $_" }
    exit 1
}
Write-Output 'Flow checks passed: Spec-driven, Spec-driven on base, Supervised, retired-flow mapping.'
