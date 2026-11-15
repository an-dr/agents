#Requires -Version 7
<# Runs the controller through each flow's gates in a throwaway repository. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$controller = Join-Path $PSScriptRoot '..' 'workflow.ps1'
$failures = [Collections.Generic.List[string]]::new()
$wipDataSkill = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' 'an-dr-ai-use-wip-data')).Path

# The test inspects and edits the state file as the user would see it.
function Get-State { (Get-Content -Raw 'tmp-agent-wip.json' | ConvertFrom-Json).sections.workflow }
function Set-State($State) {
    $data = Get-Content -Raw 'tmp-agent-wip.json' | ConvertFrom-Json
    $data.sections.workflow = $State
    $data | ConvertTo-Json -Depth 16 | Set-Content 'tmp-agent-wip.json'
}

function Invoke-Workflow {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    $output = @(& pwsh -NoProfile -NonInteractive -File $controller @Arguments -WipDataSkill $wipDataSkill 2>&1)
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
# accept at FINAL_REVIEW, then finish hands the branch over with its state.
$repo = New-Repository
try {
    Assert-Pass 'spec start' @('start', '-Flow', 'SpecDriven')
    if (-not (Test-Path 'tmp-agent-progress.html')) { $failures.Add('Progress page was not rendered at start.') }
    if (@(git status --porcelain -- tmp-agent-progress.html).Count -gt 0) { $failures.Add('Progress page is not excluded from git.') }
    if (-not (Test-Path 'tmp-agent-wip.json')) { $failures.Add('State is not in tmp-agent-wip.json.') }
    if (Test-Path '.progress') { $failures.Add('A .progress folder was created.') }
    if ((Get-Content -Raw 'tmp-agent-progress.html') -notmatch 'class="stages"') { $failures.Add('Progress page has no stage table.') }
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
    git add x.txt tmp-agent-wip.json
    git commit -q -m 'feat: x'
    Assert-Pass 'spec commit->summary' @('advance')
    Assert-Pass 'spec summary->final review' @('advance')
    Assert-Fail 'spec final review needs accept' @('advance') 'accept'
    Assert-Fail 'spec has no integrate gate' @('approve', '-Gate', 'integrate', '-Note', 'x') 'integrate'
    Assert-Pass 'spec accept' @('approve', '-Gate', 'accept', '-Note', 'accept')
    Assert-Pass 'spec final review->handover' @('advance')
    # A state written at the retired INTEGRATE phase resumes at HANDOVER.
    $legacy = Get-State
    $legacy.phase = 'INTEGRATE'
    Set-State $legacy
    $result = Invoke-Workflow 'status'
    if ($result.Code -ne 0 -or $result.Output -notmatch 'HANDOVER \| current') { $failures.Add("INTEGRATE did not resume as HANDOVER: $($result.Output)") }
    Assert-Fail 'spec handover refuses new scope' @('add-increment', '-Scope', 'more', '-Description', 'y') 'handed over'
    Assert-Pass 'spec finish' @('finish')
    $state = Get-State
    if (-not $state.finishedAt) { $failures.Add('finish did not mark the state handed over.') }
    if ($state.baseBranch -ne 'main') { $failures.Add('The state lost its base branch.') }
    $result = Invoke-Workflow 'status'
    if ($result.Output -notmatch 'Handed over') { $failures.Add("Status does not say handed over: $($result.Output)") }
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
    $state = Get-State
    $state.flow = 'DetailedAuto'
    Set-State $state
    $result = Invoke-Workflow 'status'
    if ($result.Code -ne 0 -or $result.Output -notmatch 'Spec-driven') { $failures.Add("DetailedAuto did not resume as Spec-driven: $($result.Output)") }
    $state.flow = 'Quick'
    Set-State $state
    Assert-Fail 'quick refused' @('status') 'retired Quick flow'
}
finally { Close-Repository $repo }

# Vibe: stages without gates, a handoff, and the base it started from.
$repo = New-Repository
try {
    git switch -q -c dev
    Assert-Pass 'vibe start' @('start', '-Flow', 'Vibe')
    $state = Get-State
    if ($state.phase -ne 'BUILD' -or $state.baseBranch -ne 'dev') { $failures.Add("Vibe did not start at BUILD from dev: $($state.phase) $($state.baseBranch)") }
    git switch -q -c vibe/x
    Assert-Pass 'vibe handoff goal' @('set-handoff', '-HandoffField', 'goal', '-Items', 'Make X')
    Assert-Pass 'vibe handoff next' @('set-handoff', '-HandoffField', 'next', '-Items', 'one | two')
    Assert-Fail 'vibe has no gates' @('approve', '-Gate', 'implement', '-Note', 'x') 'no gates'
    Assert-Fail 'vibe has no increments' @('add-increment', '-Scope', 'a', '-Description', 'b') 'no gates'
    Assert-Pass 'vibe build->verify' @('advance')
    Assert-Pass 'vibe verify->deliver' @('advance')
    Assert-Pass 'vibe redo' @('return-to-build')
    foreach ($n in 1..3) { Assert-Pass "vibe advance $n" @('advance') }
    Assert-Fail 'vibe land is last' @('advance') 'LAND is the last stage'
    Assert-Fail 'vibe has no finish' @('finish') 'Vibe has no HANDOVER'
    Assert-Fail 'vibe does not switch' @('switch-flow', '-Flow', 'Supervised') 'Vibe does not switch'
    $state = Get-State
    if ($state.featureBranch -ne 'vibe/x') { $failures.Add("Vibe did not record its branch: $($state.featureBranch)") }
    if ((git config --get branch.vibe/x.an-dr-base) -ne 'dev') { $failures.Add('The base was not written to the branch config.') }
    if (@($state.handoff.next).Count -ne 2) { $failures.Add('The handoff list was not stored.') }
    $page = Get-Content -Raw 'tmp-agent-progress.html'
    if ($page -notmatch 'LAND' -or $page -notmatch 'integrates onto <b>dev</b>') { $failures.Add('Vibe page lacks its stages or base.') }
}
finally { Close-Repository $repo }

# A state from before the move resumes from .progress/workflow.json.
$repo = New-Repository
try {
    Assert-Pass 'legacy path start' @('start', '-Flow', 'Supervised')
    New-Item -ItemType Directory '.progress' | Out-Null
    Get-State | ConvertTo-Json -Depth 16 | Set-Content '.progress/workflow.json'
    Remove-Item 'tmp-agent-wip.json'
    Set-Content '.progress/PROGRESS.md' 'old'
    Assert-Pass 'legacy path resumes' @('add-question', '-Text', 'q')
    if (-not (Test-Path 'tmp-agent-wip.json') -or (Test-Path '.progress')) { $failures.Add('The legacy state was not moved into tmp-agent-wip.json.') }
    if (@((Get-State).questions).Count -ne 1) { $failures.Add('The moved state lost its content.') }
}
finally { Close-Repository $repo }

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Output "FAIL: $_" }
    exit 1
}
Write-Output 'Flow checks passed: Spec-driven with handover, Spec-driven on base, Supervised, Vibe, retired-flow, retired-phase and legacy-path mapping.'
