#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory)]
    [ValidateSet('start', 'status', 'advance', 'return-to-build', 'approve', 'add-increment', 'move-increment', 'defer-increment', 'remove-increment', 'add-request', 'remove-request', 'set-requirement', 'add-question', 'answer-question', 'dismiss-question', 'finish')]
    [string]$Command,

    [ValidateSet('Detailed', 'DetailedAuto', 'Quick')]
    [string]$Flow,
    [string]$Goal,
    [string]$Constraints,
    [string]$Done,
    [string]$OutOfScope,
    [ValidateSet('goal', 'constraints', 'done', 'outOfScope')]
    [string]$Field,
    [string]$Value,
    [ValidateSet('intake', 'implement', 'verify', 'integrate')]
    [string]$Gate,
    [string]$Note,
    [string]$Text,
    [string]$Answer,
    [string]$Scope,
    [string]$Description,
    [int]$At,
    [int]$Number,
    [int]$To
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepositoryRoot {
    $root = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $root) {
        throw 'Run the workflow controller inside a Git repository.'
    }
    return $root.Trim()
}

function Get-WorkflowPath {
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    return Join-Path $RepositoryRoot '.progress/workflow.json'
}

function Enter-WorkflowLock {
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $bytes = [Text.Encoding]::UTF8.GetBytes($RepositoryRoot.ToLowerInvariant())
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
    $path = Join-Path ([IO.Path]::GetTempPath()) "agents-workflow-$hash.lock"
    try {
        $stream = [IO.File]::Open($path, 'OpenOrCreate', 'ReadWrite', 'None')
    }
    catch {
        throw 'Another workflow controller operation is already running for this repository.'
    }
    return [pscustomobject]@{ path = $path; stream = $stream }
}

function Exit-WorkflowLock {
    param([Parameter(Mandatory)]$Lock)

    $Lock.stream.Dispose()
    Remove-Item -Force -LiteralPath $Lock.path -ErrorAction SilentlyContinue
}

function Get-WorkflowState {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No active workflow exists at '$Path'."
    }
    $state = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    # Phases that no longer exist collapse into the one that replaced them.
    if ($state.phase -in @('MR', 'MERGE_READY', 'INTEGRATE_READY')) {
        $state.phase = 'SUMMARY'
    }
    if ($state.phase -eq 'MERGE') {
        $state.phase = 'INTEGRATE'
    }
    # START collected nothing; INTAKE collects the request list. A workflow
    # written before the rename resumes at the phase that replaced it, and its
    # requirements — mandatory back then — already satisfy the INTAKE exit.
    $wasStart = $state.phase -eq 'START'
    if ($wasStart) {
        $state.phase = 'INTAKE'
    }
    if (-not $state.PSObject.Properties['questions']) {
        $state | Add-Member -NotePropertyName questions -NotePropertyValue @()
    }
    if (-not $state.PSObject.Properties['requests']) {
        $state | Add-Member -NotePropertyName requests -NotePropertyValue @()
    }
    # A workflow that stopped in START has no request list and INTAKE will not
    # release an empty one, so its goal becomes the first request. Later phases
    # are left alone: they never return to INTAKE, and an invented request would
    # only mislead the reconciliation at SUMMARY.
    if ($wasStart -and @($state.requests).Count -eq 0 -and $state.requirements.goal) {
        $state.requests = @([pscustomobject]@{
                id     = [guid]::NewGuid().ToString('N')
                number = 1
                text   = [string]$state.requirements.goal
            })
    }
    # Approvals under retired gate names are dropped rather than remapped: the
    # gates they authorized no longer exist, so the user re-authorizes under the
    # current ones. The history entries keep the record of what was approved.
    $state.approvals = @(@($state.approvals).Where({ $_.gate -in @('intake', 'implement', 'verify', 'integrate') }))
    Assert-WorkflowState -State $state
    return $state
}

function Assert-WorkflowTimestamp {
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Name
    )

    if ($Value -is [datetime] -or $Value -is [datetimeoffset]) { return }
    $parsed = [datetimeoffset]::MinValue
    if (-not [datetimeoffset]::TryParse(
            [string]$Value,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind,
            [ref]$parsed
        )) {
        throw "Workflow state contains an invalid '$Name' timestamp."
    }
}

function Get-WorkflowQuestion {
    <# Returns the question list, tolerating state written before it existed. #>
    param([Parameter(Mandatory)]$State)

    if (-not $State.PSObject.Properties['questions']) { return @() }
    return @($State.questions)
}

function Get-OpenQuestion {
    <# Returns the questions still waiting on the user. #>
    param([Parameter(Mandatory)]$State)

    return @((Get-WorkflowQuestion -State $State).Where({ $_.status -eq 'open' }))
}

function Resolve-Question {
    <# Returns the question at -Number, or explains why it cannot be used. #>
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][AllowNull()][object]$Number,
        [Parameter(Mandatory)]$Bound
    )

    if (-not $Bound.ContainsKey('Number')) {
        throw '-Number is required; it is the number shown in the question table.'
    }
    $questions = @(Get-WorkflowQuestion -State $State)
    if ($Number -lt 1 -or $Number -gt $questions.Count) {
        throw "Question numbers run from 1 to $($questions.Count)."
    }
    return $questions[$Number - 1]
}

function Get-WorkflowRequest {
    <# Returns the request list, tolerating state written before it existed. #>
    param([Parameter(Mandatory)]$State)

    if (-not $State.PSObject.Properties['requests']) { return @() }
    return @($State.requests)
}

function Test-RequirementsComplete {
    <# True when INTAKE has distilled all four facts the later phases read. #>
    param([Parameter(Mandatory)]$State)

    foreach ($property in @('goal', 'constraints', 'done', 'outOfScope')) {
        if ([string]::IsNullOrWhiteSpace([string]$State.requirements.$property)) {
            return $false
        }
    }
    return $true
}

function Get-WorkflowPhases {
    param([Parameter(Mandatory)][string]$Flow)

    if ($Flow -eq 'Quick') {
        return @('INTAKE', 'DESIGN', 'BUILD', 'VERIFY', 'COMMIT')
    }
    if ($Flow -eq 'Detailed') {
        return @(
            'INTAKE', 'DESIGN', 'SPLIT', 'BRANCH', 'BUILD', 'VERIFY', 'COMMIT',
            'SUMMARY', 'INTEGRATE'
        )
    }
    return @(
        'INTAKE', 'DESIGN', 'SPLIT', 'BRANCH', 'BUILD', 'VERIFY', 'COMMIT',
        'SUMMARY', 'FINAL_REVIEW', 'INTEGRATE'
    )
}

function Assert-WorkflowState {
    param([Parameter(Mandatory)]$State)

    if ($State.schemaVersion -ne 1) {
        throw "Unsupported workflow schema version '$($State.schemaVersion)'."
    }
    if ($State.flow -notin @('Quick', 'Detailed', 'DetailedAuto')) {
        throw "Unsupported workflow flow '$($State.flow)'."
    }
    $validPhases = @(Get-WorkflowPhases -Flow $State.flow)
    if ($State.phase -notin $validPhases) {
        throw "Phase '$($State.phase)' is invalid for flow '$($State.flow)'."
    }
    foreach ($property in @('baseBranch', 'baseCommit', 'createdAt', 'updatedAt')) {
        if ([string]::IsNullOrWhiteSpace([string]$State.$property)) {
            throw "Workflow state is missing '$property'."
        }
    }
    # INTAKE is where the four facts are written, so it is the one phase allowed
    # to hold an incomplete set; every later phase reads them as settled.
    if ($State.phase -ne 'INTAKE') {
        foreach ($property in @('goal', 'constraints', 'done', 'outOfScope')) {
            if ([string]::IsNullOrWhiteSpace([string]$State.requirements.$property)) {
                throw "Workflow requirements are missing '$property'."
            }
        }
    }
    Assert-WorkflowTimestamp -Value $State.createdAt -Name 'createdAt'
    Assert-WorkflowTimestamp -Value $State.updatedAt -Name 'updatedAt'
    & git cat-file -e "$($State.baseCommit)^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Workflow base commit '$($State.baseCommit)' does not exist in this repository."
    }

    $increments = @($State.increments)
    if ($State.flow -eq 'Quick' -and $increments.Count -gt 0) {
        throw 'Quick workflow state cannot contain increments.'
    }
    $seenIds = @{}
    $expectedNumber = 1
    $lastRank = -1
    foreach ($increment in $increments) {
        if ([string]::IsNullOrWhiteSpace([string]$increment.id) -or $seenIds.ContainsKey($increment.id)) {
            throw "Workflow contains a missing or duplicate increment ID '$($increment.id)'."
        }
        $seenIds[$increment.id] = $true
        if ([int]$increment.number -ne $expectedNumber) {
            throw "Expected increment number $expectedNumber, found '$($increment.number)'."
        }
        if ($increment.status -notin @('planned', 'in_progress', 'verified', 'completed')) {
            throw "Increment $expectedNumber has invalid status '$($increment.status)'."
        }
        foreach ($property in @('scope', 'description')) {
            if ([string]::IsNullOrWhiteSpace([string]$increment.$property)) {
                throw "Increment $expectedNumber is missing '$property'."
            }
        }
        $rank = switch ($increment.status) {
            'completed' { 0 }
            { $_ -in @('in_progress', 'verified') } { 1 }
            'planned' { 2 }
        }
        if ($rank -lt $lastRank) {
            throw 'Increment statuses must remain ordered as completed, active, then planned.'
        }
        $lastRank = $rank
        $expectedNumber++
    }

    $active = @($increments | Where-Object { $_.status -in @('in_progress', 'verified') })
    if ($State.currentIncrementId) {
        $current = @($increments | Where-Object { $_.id -eq $State.currentIncrementId })
        if ($current.Count -ne 1 -or $active.Count -ne 1) {
            throw 'currentIncrementId must identify the only active increment.'
        }
        $expectedStatus = if ($State.phase -eq 'COMMIT') { 'verified' } else { 'in_progress' }
        if ($current[0].status -ne $expectedStatus -or $State.phase -notin @('BUILD', 'VERIFY', 'COMMIT')) {
            throw "Active increment status is inconsistent with phase '$($State.phase)'."
        }
    }
    elseif ($active.Count -gt 0) {
        throw 'Workflow has an active increment without currentIncrementId.'
    }
    if ($State.flow -ne 'Quick' -and $State.phase -in @('BUILD', 'VERIFY', 'COMMIT') -and
        -not $State.currentIncrementId) {
        throw "Detailed phase '$($State.phase)' requires an active increment."
    }
    if ($State.phase -eq 'COMMIT' -and [string]::IsNullOrWhiteSpace([string]$State.commitBaseline)) {
        throw 'COMMIT phase requires commitBaseline.'
    }
    if ($State.phase -ne 'COMMIT' -and $State.commitBaseline) {
        throw "commitBaseline is only valid during COMMIT, not '$($State.phase)'."
    }
    if ($State.flow -ne 'Quick' -and $State.phase -in @('SUMMARY', 'FINAL_REVIEW', 'INTEGRATE') -and
        @($increments | Where-Object { $_.status -ne 'completed' }).Count -gt 0) {
        throw "Phase '$($State.phase)' requires every increment to be completed."
    }
    if ($State.flow -ne 'Quick' -and $State.phase -notin @('INTAKE', 'DESIGN', 'SPLIT', 'BRANCH') -and
        [string]::IsNullOrWhiteSpace([string]$State.featureBranch)) {
        throw "Phase '$($State.phase)' requires featureBranch."
    }

    $expectedNumber = 1
    $seenRequestIds = @{}
    foreach ($request in @(Get-WorkflowRequest -State $State)) {
        if ([string]::IsNullOrWhiteSpace([string]$request.id) -or $seenRequestIds.ContainsKey($request.id)) {
            throw "Workflow contains a missing or duplicate request ID '$($request.id)'."
        }
        $seenRequestIds[$request.id] = $true
        if ([int]$request.number -ne $expectedNumber) {
            throw "Expected request number $expectedNumber, found '$($request.number)'."
        }
        if ([string]::IsNullOrWhiteSpace([string]$request.text)) {
            throw "Request $expectedNumber is missing its text."
        }
        $expectedNumber++
    }

    $expectedNumber = 1
    $seenQuestionIds = @{}
    foreach ($question in @(Get-WorkflowQuestion -State $State)) {
        if ([string]::IsNullOrWhiteSpace([string]$question.id) -or $seenQuestionIds.ContainsKey($question.id)) {
            throw "Workflow contains a missing or duplicate question ID '$($question.id)'."
        }
        $seenQuestionIds[$question.id] = $true
        if ([int]$question.number -ne $expectedNumber) {
            throw "Expected question number $expectedNumber, found '$($question.number)'."
        }
        if ($question.status -notin @('open', 'answered', 'dismissed')) {
            throw "Question $expectedNumber has invalid status '$($question.status)'."
        }
        if ([string]::IsNullOrWhiteSpace([string]$question.text)) {
            throw "Question $expectedNumber is missing its text."
        }
        if ($question.status -ne 'open' -and [string]::IsNullOrWhiteSpace([string]$question.answer)) {
            throw "Question $expectedNumber is $($question.status) but records no answer."
        }
        $expectedNumber++
    }

    foreach ($approval in @($State.approvals)) {
        if ($approval.gate -notin @('intake', 'implement', 'verify', 'integrate') -or
            [string]::IsNullOrWhiteSpace([string]$approval.note)) {
            throw 'Workflow contains a malformed approval record.'
        }
        Assert-WorkflowTimestamp -Value $approval.approvedAt -Name 'approval approvedAt'
    }
    foreach ($entry in @($State.history)) {
        if ([string]::IsNullOrWhiteSpace([string]$entry.action) -or
            [string]::IsNullOrWhiteSpace([string]$entry.detail)) {
            throw 'Workflow contains a malformed history record.'
        }
        Assert-WorkflowTimestamp -Value $entry.at -Name 'history at'
    }
}

function Assert-WorkflowBranch {
    param([Parameter(Mandatory)]$State)

    if (-not $State.featureBranch) {
        return
    }
    $branch = (git branch --show-current).Trim()
    if ($branch -ne $State.featureBranch) {
        throw "Workflow branch '$($State.featureBranch)' is required; current branch is '$branch'."
    }
}

function Add-HistoryEntry {
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string]$Detail
    )

    $entry = [pscustomobject]@{
        at     = (Get-Date).ToUniversalTime().ToString('o')
        action = $Action
        detail = $Detail
    }
    $State.history = @($State.history) + $entry
}

function Get-ProgressMarkdownPath {
    param([Parameter(Mandatory)][string]$WorkflowPath)

    return Join-Path (Split-Path -Parent $WorkflowPath) 'PROGRESS.md'
}

function Write-ProgressMarkdown {
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][string]$Path
    )

    $flowLabel = if ($State.flow -eq 'DetailedAuto') { 'Detailed Auto' } else { $State.flow }
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add('# Progress')
    $lines.Add('')
    $lines.Add("**Flow:** $flowLabel")
    $lines.Add("**Phase:** $($State.phase)")
    # During INTAKE any of the four can still be unwritten, so each says so
    # rather than rendering a blank the reader has to interpret.
    $lines.Add("**Goal:** $(if ($State.requirements.goal) { $State.requirements.goal } else { '_not yet defined_' })")
    $lines.Add("**Done when:** $(if ($State.requirements.done) { $State.requirements.done } else { '_not yet defined_' })")
    if ($State.requirements.constraints) {
        $lines.Add("**Constraints:** $($State.requirements.constraints)")
    }
    if ($State.requirements.outOfScope) {
        $lines.Add("**Out of scope:** $($State.requirements.outOfScope)")
    }
    $lines.Add('')

    $requests = @(Get-WorkflowRequest -State $State)
    if ($requests.Count -gt 0) {
        $lines.Add('## Requests')
        $lines.Add('')
        foreach ($request in $requests) {
            $lines.Add("- $($request.text)")
        }
        $lines.Add('')
    }

    $increments = @($State.increments)
    if ($increments.Count -gt 0) {
        $lines.Add('## Iterations')
        $lines.Add('')
        foreach ($increment in $increments) {
            $marker = switch ($increment.status) {
                'completed' { 'x' }
                default { ' ' }
            }
            $statusLabel = switch ($increment.status) {
                'in_progress' { 'in progress' }
                default { $increment.status }
            }
            $lines.Add("- [$marker] **$($increment.scope)** ($statusLabel) — $($increment.description)")
        }
        $lines.Add('')
    }

    $questions = @(Get-WorkflowQuestion -State $State)
    if ($questions.Count -gt 0) {
        $lines.Add('## Questions')
        $lines.Add('')
        foreach ($question in $questions) {
            $marker = if ($question.status -eq 'open') { ' ' } else { 'x' }
            $suffix = switch ($question.status) {
                'answered' { " — $($question.answer)" }
                'dismissed' { " — dismissed: $($question.answer)" }
                default { '' }
            }
            $lines.Add("- [$marker] $($question.text)$suffix")
        }
        $lines.Add('')
    }

    $lines.Add("_Last updated: $($State.updatedAt)_")

    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $temporaryPath = Join-Path $directory ('.progress-md-{0}.tmp' -f [guid]::NewGuid())
    try {
        [IO.File]::WriteAllText($temporaryPath, ($lines -join "`n"), [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporaryPath, $Path, $true)
    }
    finally {
        Remove-Item -Force -LiteralPath $temporaryPath -ErrorAction SilentlyContinue
    }
}

function Save-WorkflowState {
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][string]$Path
    )

    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $State.updatedAt = (Get-Date).ToUniversalTime().ToString('o')
    Assert-WorkflowState -State $State
    $temporaryPath = Join-Path $directory ('.workflow-{0}.tmp' -f [guid]::NewGuid())
    $json = $State | ConvertTo-Json -Depth 12
    try {
        [IO.File]::WriteAllText($temporaryPath, $json, [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporaryPath, $Path, $true)
    }
    finally {
        Remove-Item -Force -LiteralPath $temporaryPath -ErrorAction SilentlyContinue
    }
    Write-ProgressMarkdown -State $State -Path (Get-ProgressMarkdownPath -WorkflowPath $Path)
}

function Test-Approval {
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][string]$GateName
    )

    $incrementId = if ($GateName -eq 'verify') { $State.currentIncrementId } else { $null }
    return @($State.approvals).Where({
        $_.gate -eq $GateName -and $_.phase -eq $State.phase -and
        ($GateName -ne 'verify' -or $_.incrementId -eq $incrementId)
    }).Count -gt 0
}

function Assert-Approval {
    param(
        [Parameter(Mandatory)]$State,
        [Parameter(Mandatory)][string]$GateName
    )

    if (-not (Test-Approval -State $State -GateName $GateName)) {
        throw "The '$GateName' approval is required before leaving $($State.phase)."
    }
}

function Get-CurrentIncrement {
    param([Parameter(Mandatory)]$State)

    if (-not $State.currentIncrementId) {
        return $null
    }
    return @($State.increments).Where({ $_.id -eq $State.currentIncrementId }, 'First')[0]
}

function Set-IncrementNumbers {
    param([Parameter(Mandatory)]$State)

    $number = 1
    foreach ($increment in @($State.increments)) {
        $increment.number = $number
        $number++
    }
}

function Start-NextIncrement {
    param([Parameter(Mandatory)]$State)

    $next = @($State.increments).Where({ $_.status -eq 'planned' }, 'First')[0]
    if (-not $next) {
        throw 'No planned increment remains.'
    }
    $next.status = 'in_progress'
    $State.currentIncrementId = $next.id
    $State.phase = 'BUILD'
}

function Get-GitHead {
    $head = git rev-parse HEAD
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to read the current Git commit.'
    }
    return $head.Trim()
}

function Assert-IncrementCommitted {
    param([Parameter(Mandatory)]$State)

    $head = Get-GitHead
    if ($head -eq $State.commitBaseline) {
        throw 'Commit the current increment, including .progress/workflow.json, before advancing.'
    }
    $changes = git status --porcelain
    if ($changes) {
        throw 'The working tree must be clean before advancing from COMMIT.'
    }
}

function Show-WorkflowStatus {
    param(
        [Parameter(Mandatory)]$State,
        [ValidateSet('active', 'finished')]
        [string]$Status = 'active'
    )

    $flowLabel = if ($State.flow -eq 'DetailedAuto') { 'Detailed Auto' } else { $State.flow }
    $increment = Get-CurrentIncrement -State $State
    $incrementLabel = '—'
    if ($increment) {
        $incrementLabel = "$($increment.number)/$(@($State.increments).Count) — $($increment.scope)"
    }
    elseif (@($State.increments).Count -gt 0) {
        $incrementLabel = "$(@($State.increments).Count) total"
    }

    Write-Output '<!-- AGENT INSTRUCTION: Present these workflow status tables to the user after every controller change. -->'
    Write-Output '| Flow | Status | Increment |'
    Write-Output '| --- | --- | --- |'
    Write-Output "| $flowLabel | $Status | $incrementLabel |"
    Write-Output ''
    Write-Output '| Phase | Status |'
    Write-Output '| --- | --- |'
    $phases = @(Get-WorkflowPhases -Flow $State.flow)
    $currentPhaseIndex = [Array]::IndexOf($phases, [string]$State.phase)
    for ($index = 0; $index -lt $phases.Count; $index++) {
        $phaseStatus = if ($Status -eq 'finished' -or $index -lt $currentPhaseIndex) {
            'completed'
        }
        elseif ($index -eq $currentPhaseIndex) {
            'current'
        }
        else {
            'pending'
        }
        Write-Output "| $($phases[$index]) | $phaseStatus |"
    }

    if (@($State.increments).Count -gt 0) {
        Write-Output ''
        Write-Output '| # | Increment | Status |'
        Write-Output '| ---: | --- | --- |'
    }
    foreach ($item in @($State.increments)) {
        $incrementText = "$($item.scope) — $($item.description)".Replace('|', '\|')
        Write-Output "| $($item.number) | $incrementText | $($item.status) |"
    }

    $requests = @(Get-WorkflowRequest -State $State)
    if ($requests.Count -gt 0) {
        Write-Output ''
        Write-Output '| # | Request |'
        Write-Output '| ---: | --- |'
        foreach ($item in $requests) {
            Write-Output "| $($item.number) | $(([string]$item.text).Replace('|', '\|')) |"
        }
    }

    $questions = @(Get-WorkflowQuestion -State $State)
    if ($questions.Count -gt 0) {
        Write-Output ''
        Write-Output '| # | Question | Status | Answer |'
        Write-Output '| ---: | --- | --- | --- |'
        foreach ($item in $questions) {
            $questionText = ([string]$item.text).Replace('|', '\|')
            $answerText = if ($item.answer) { ([string]$item.answer).Replace('|', '\|') } else { '—' }
            Write-Output "| $($item.number) | $questionText | $($item.status) | $answerText |"
        }
    }
    Write-Output ''
    $openCount = @(Get-OpenQuestion -State $State).Count
    if ($openCount -gt 0) {
        Write-Output "Open questions: $openCount — the implement gate stays closed until each is answered or dismissed."
    }
    if ($Status -eq 'active' -and $State.phase -eq 'INTAKE') {
        $missing = @('goal', 'constraints', 'done', 'outOfScope').Where({
            [string]::IsNullOrWhiteSpace([string]$State.requirements.$_)
        })
        if ($missing.Count -gt 0) {
            Write-Output "Intake is open — keep recording requests. Still to distil: $($missing -join ', ')."
        }
        else {
            Write-Output 'Intake is open — keep recording requests until the user says the list is complete.'
        }
    }
    Write-Output "Goal: $(if ($State.requirements.goal) { $State.requirements.goal } else { '(not yet defined)' })"
    Write-Output "Updated: $($State.updatedAt)"
}

$repositoryRoot = Get-RepositoryRoot
$workflowPath = Get-WorkflowPath -RepositoryRoot $repositoryRoot
$workflowLock = $null
if ($Command -ne 'status') {
    $workflowLock = Enter-WorkflowLock -RepositoryRoot $repositoryRoot
}

try {
switch ($Command) {
    'start' {
        if (Test-Path -LiteralPath $workflowPath) {
            throw 'An active workflow already exists. Resume it or finish it first.'
        }
        # Only the flow is required: the four facts are what INTAKE produces, so
        # demanding them here would put requirement-gathering before the phase
        # that gathers it. Any that are known up front seed the state.
        if ([string]::IsNullOrWhiteSpace([string]$Flow)) {
            throw '-Flow is required when starting a workflow.'
        }

        $baseBranch = (git branch --show-current).Trim()
        if ([string]::IsNullOrWhiteSpace($baseBranch)) {
            throw 'Workflows cannot start from a detached HEAD.'
        }
        $now = (Get-Date).ToUniversalTime().ToString('o')
        $baseCommit = Get-GitHead
        $state = [pscustomobject]@{
            schemaVersion      = 1
            flow               = $Flow
            phase              = 'INTAKE'
            baseBranch         = $baseBranch
            baseCommit         = $baseCommit
            featureBranch      = $null
            requirements       = [pscustomobject]@{
                goal       = $Goal
                constraints = $Constraints
                done       = $Done
                outOfScope = $OutOfScope
            }
            currentIncrementId = $null
            commitBaseline     = $null
            increments         = @()
            requests           = @()
            questions          = @()
            approvals          = @()
            history            = @()
            createdAt          = $now
            updatedAt          = $now
        }
        Add-HistoryEntry -State $state -Action 'start' -Detail "Started $Flow workflow."
        Save-WorkflowState -State $state -Path $workflowPath
        Show-WorkflowStatus -State $state
    }

    'status' {
        $state = Get-WorkflowState -Path $workflowPath
        Show-WorkflowStatus -State $state
    }

    'approve' {
        $state = Get-WorkflowState -Path $workflowPath
        Assert-WorkflowBranch -State $state
        if (-not $Gate) {
            throw '-Gate is required for approve.'
        }
        if ([string]::IsNullOrWhiteSpace($Note)) {
            throw '-Note is required to record the approval evidence.'
        }
        # The user says intake once, when the request list is complete; implement
        # once, at the last phase before code is written; and integrate once, at
        # the review of the finished branch. Detailed Auto keeps all three: what
        # it automates is the per-increment verification in between.
        $expected = switch ($state.phase) {
            'INTAKE' { if ($state.flow -eq 'Quick') { $null } else { 'intake' } }
            'DESIGN' { if ($state.flow -eq 'Quick') { 'implement' } else { $null } }
            'SPLIT' { 'implement' }
            'VERIFY' { if ($state.flow -eq 'DetailedAuto') { $null } else { 'verify' } }
            'SUMMARY' { if ($state.flow -eq 'Detailed') { 'integrate' } else { $null } }
            'FINAL_REVIEW' { 'integrate' }
            default { $null }
        }
        if ($state.flow -eq 'DetailedAuto' -and $state.phase -in @('VERIFY', 'SUMMARY')) {
            throw 'Detailed Auto records its own verification; the user approves at INTAKE, SPLIT, and FINAL_REVIEW.'
        }
        if (-not $expected) {
            throw "$($state.phase) has no approval gate. Advance instead."
        }
        if ($Gate -ne $expected) {
            throw "Gate '$Gate' is not valid during $($state.phase). Expected '$expected'."
        }
        if ($Gate -eq 'implement') {
            $open = @(Get-OpenQuestion -State $state)
            if ($open.Count -gt 0) {
                $detail = ($open | ForEach-Object { "  $($_.number)  $($_.text)" }) -join [Environment]::NewLine
                throw ("$($open.Count) question(s) are still open. Answer or dismiss each one " +
                    "before authorizing implementation:$([Environment]::NewLine)$detail")
            }
        }
        $state.approvals = @($state.approvals) + [pscustomobject]@{
            gate        = $Gate
            phase       = $state.phase
            incrementId = if ($Gate -eq 'verify') { $state.currentIncrementId } else { $null }
            note        = $Note
            approvedAt  = (Get-Date).ToUniversalTime().ToString('o')
        }
        Add-HistoryEntry -State $state -Action 'approve' -Detail "Approved $Gate during $($state.phase)."
        Save-WorkflowState -State $state -Path $workflowPath
        Show-WorkflowStatus -State $state
    }

    # INTAKE accumulates what the user wants from this branch, one request at a
    # time, across as many messages as it takes. The list stays in state for the
    # whole workflow so SUMMARY can check the branch against what was asked for.
    'add-request' {
        $state = Get-WorkflowState -Path $workflowPath
        Assert-WorkflowBranch -State $state
        if ($state.phase -ne 'INTAKE') {
            throw ("Requests are collected during INTAKE, not '$($state.phase)'. " +
                'New scope after intake closes becomes an increment.')
        }
        if ([string]::IsNullOrWhiteSpace($Text)) {
            throw '-Text is required for add-request.'
        }
        $requests = [Collections.ArrayList]@(Get-WorkflowRequest -State $state)
        $request = [pscustomobject]@{
            id     = [guid]::NewGuid().ToString('N')
            number = $requests.Count + 1
            text   = $Text
        }
        $requests.Add($request) | Out-Null
        $state.requests = @($requests)
        # The intake approval means "this list is complete"; a later request
        # makes it untrue, so the user closes the longer list again.
        $state.approvals = @($state.approvals).Where({ $_.gate -ne 'intake' })
        Add-HistoryEntry -State $state -Action 'add-request' -Detail "Recorded request $($request.number): $Text"
        Save-WorkflowState -State $state -Path $workflowPath
        Show-WorkflowStatus -State $state
    }

    'remove-request' {
        $state = Get-WorkflowState -Path $workflowPath
        Assert-WorkflowBranch -State $state
        if ($state.phase -ne 'INTAKE') {
            throw "Requests can only be removed during INTAKE, not '$($state.phase)'."
        }
        if (-not $PSBoundParameters.ContainsKey('Number')) {
            throw '-Number is required; it is the number shown in the request table.'
        }
        $requests = [Collections.ArrayList]@(Get-WorkflowRequest -State $state)
        if ($Number -lt 1 -or $Number -gt $requests.Count) {
            throw "Request numbers run from 1 to $($requests.Count)."
        }
        $request = $requests[$Number - 1]
        $requests.RemoveAt($Number - 1)
        $number = 1
        foreach ($item in $requests) {
            $item.number = $number
            $number++
        }
        $state.requests = @($requests)
        $state.approvals = @($state.approvals).Where({ $_.gate -ne 'intake' })
        Add-HistoryEntry -State $state -Action 'remove-request' -Detail "Removed request ${Number}: $($request.text)"
        Save-WorkflowState -State $state -Path $workflowPath
        Show-WorkflowStatus -State $state
    }

    # Distils the accumulated requests into the four facts every later phase
    # reads. INTAKE cannot be left until all four are written.
    'set-requirement' {
        $state = Get-WorkflowState -Path $workflowPath
        Assert-WorkflowBranch -State $state
        if ([string]::IsNullOrWhiteSpace($Field)) {
            throw '-Field is required for set-requirement.'
        }
        if ([string]::IsNullOrWhiteSpace($Value)) {
            throw '-Value is required for set-requirement; never record an invented fact.'
        }
        $state.requirements.$Field = $Value
        Add-HistoryEntry -State $state -Action 'set-requirement' -Detail "Set $Field."
        Save-WorkflowState -State $state -Path $workflowPath
        Show-WorkflowStatus -State $state
    }

    # INTAKE and DESIGN collect what the agent cannot decide alone instead of
    # interrupting for each one; the implement gate is closed until none is open.
    'add-question' {
        $state = Get-WorkflowState -Path $workflowPath
        Assert-WorkflowBranch -State $state
        if ([string]::IsNullOrWhiteSpace($Text)) {
            throw '-Text is required for add-question.'
        }
        $questions = [Collections.ArrayList]@(Get-WorkflowQuestion -State $state)
        $question = [pscustomobject]@{
            id     = [guid]::NewGuid().ToString('N')
            number = $questions.Count + 1
            status = 'open'
            text   = $Text
            answer = $null
        }
        $questions.Add($question) | Out-Null
        $state.questions = @($questions)
        Add-HistoryEntry -State $state -Action 'add-question' -Detail "Recorded question $($question.number): $Text"
        Save-WorkflowState -State $state -Path $workflowPath
        Show-WorkflowStatus -State $state
    }

    'answer-question' {
        $state = Get-WorkflowState -Path $workflowPath
        Assert-WorkflowBranch -State $state
        $question = Resolve-Question -State $state -Number $Number -Bound $PSBoundParameters
        if ([string]::IsNullOrWhiteSpace($Answer)) {
            throw '-Answer is required for answer-question.'
        }
        $question.status = 'answered'
        $question.answer = $Answer
        Add-HistoryEntry -State $state -Action 'answer-question' -Detail "Answered question $($question.number)."
        Save-WorkflowState -State $state -Path $workflowPath
        Show-WorkflowStatus -State $state
    }

    'dismiss-question' {
        $state = Get-WorkflowState -Path $workflowPath
        Assert-WorkflowBranch -State $state
        $question = Resolve-Question -State $state -Number $Number -Bound $PSBoundParameters
        if ([string]::IsNullOrWhiteSpace($Answer)) {
            throw '-Answer is required for dismiss-question; record why it stopped mattering.'
        }
        $question.status = 'dismissed'
        $question.answer = $Answer
        Add-HistoryEntry -State $state -Action 'dismiss-question' -Detail "Dismissed question $($question.number)."
        Save-WorkflowState -State $state -Path $workflowPath
        Show-WorkflowStatus -State $state
    }

    'add-increment' {
        $state = Get-WorkflowState -Path $workflowPath
        Assert-WorkflowBranch -State $state
        if ($state.flow -eq 'Quick') {
            throw 'Quick workflows do not use increments.'
        }
        if ([string]::IsNullOrWhiteSpace($Scope) -or [string]::IsNullOrWhiteSpace($Description)) {
            throw '-Scope and -Description are required for add-increment.'
        }
        if ($state.phase -eq 'INTEGRATE') {
            throw 'The approved workflow is ready to integrate. Start a follow-up workflow for new scope.'
        }

        $increments = [Collections.ArrayList]@(@($state.increments))
        $position = if ($PSBoundParameters.ContainsKey('At')) { $At } else { $increments.Count + 1 }
        if ($position -lt 1 -or $position -gt $increments.Count + 1) {
            throw "-At must be between 1 and $($increments.Count + 1)."
        }
        $fixedCount = @($state.increments).Where({ $_.status -ne 'planned' }).Count
        if ($position -le $fixedCount) {
            throw "Completed or active increments are fixed; insert at $($fixedCount + 1) or later."
        }
        $increment = [pscustomobject]@{
            id          = [guid]::NewGuid().ToString('N')
            number      = 0
            status      = 'planned'
            scope       = $Scope
            description = $Description
        }
        $increments.Insert($position - 1, $increment)
        $state.increments = @($increments)
        Set-IncrementNumbers -State $state
        if ($state.phase -in @('SUMMARY', 'FINAL_REVIEW')) {
            $state.phase = 'SPLIT'
            $state.approvals = @($state.approvals).Where({ $_.gate -notin @('implement', 'integrate') })
        }
        Add-HistoryEntry -State $state -Action 'add-increment' -Detail "Inserted increment ${position}: $Scope"
        Save-WorkflowState -State $state -Path $workflowPath
        Show-WorkflowStatus -State $state
    }

    'move-increment' {
        $state = Get-WorkflowState -Path $workflowPath
        Assert-WorkflowBranch -State $state
        if (-not $PSBoundParameters.ContainsKey('Number') -or -not $PSBoundParameters.ContainsKey('To')) {
            throw '-Number and -To are required for move-increment.'
        }
        $increments = [Collections.ArrayList]@(@($state.increments))
        if ($Number -lt 1 -or $Number -gt $increments.Count -or $To -lt 1 -or $To -gt $increments.Count) {
            throw "Increment positions must be between 1 and $($increments.Count)."
        }
        $increment = $increments[$Number - 1]
        if ($increment.status -ne 'planned') {
            throw 'Only planned increments can be moved.'
        }
        $fixedCount = @($state.increments).Where({ $_.status -ne 'planned' }).Count
        if ($To -le $fixedCount) {
            throw "Planned increments must remain after the first $fixedCount fixed increment(s)."
        }
        $increments.RemoveAt($Number - 1)
        $increments.Insert($To - 1, $increment)
        $state.increments = @($increments)
        Set-IncrementNumbers -State $state
        Add-HistoryEntry -State $state -Action 'move-increment' -Detail "Moved increment $Number to $To."
        Save-WorkflowState -State $state -Path $workflowPath
        Show-WorkflowStatus -State $state
    }

    # Reorders the active increment itself, which move-increment cannot: the
    # state invariant keeps the active increment ahead of every planned one, so
    # it can only change position by returning to 'planned' while the increment
    # that replaces it becomes active in the same operation.
    'defer-increment' {
        $state = Get-WorkflowState -Path $workflowPath
        Assert-WorkflowBranch -State $state
        if (-not $PSBoundParameters.ContainsKey('To')) {
            throw '-To is required for defer-increment.'
        }
        if ($state.phase -ne 'BUILD') {
            throw "defer-increment is only available in BUILD, not '$($state.phase)'."
        }
        $current = Get-CurrentIncrement -State $state
        if (-not $current) {
            throw 'There is no active increment to defer.'
        }
        # A clean tree is the evidence that nothing was built for this increment
        # yet. Work already committed under it cannot be detected here, so the
        # caller must not defer an increment whose commits are on the branch.
        # `.progress/` is excluded because the controller rewrites it on every
        # command, which would otherwise make this guard block itself.
        $changes = @(git status --porcelain -- . ':(exclude).progress')
        if ($changes.Count -gt 0) {
            throw 'The working tree must be clean, apart from .progress, to defer the active increment.'
        }

        $increments = [Collections.ArrayList]@(@($state.increments))
        $position = $increments.IndexOf($current)
        $completedCount = @($state.increments).Where({ $_.status -eq 'completed' }).Count
        if (@($state.increments).Where({ $_.status -eq 'planned' }).Count -lt 1) {
            throw 'No planned increment remains to take over from the deferred one.'
        }
        # The increment taking over occupies the first post-completed slot, so a
        # deferral has to land at least one place behind it.
        $earliest = $completedCount + 2
        if ($To -lt $earliest -or $To -gt $increments.Count) {
            throw "The deferred increment must move to a position between $earliest and $($increments.Count)."
        }

        $current.status = 'planned'
        $state.currentIncrementId = $null
        $increments.RemoveAt($position)
        $increments.Insert($To - 1, $current)
        $state.increments = @($increments)
        Start-NextIncrement -State $state
        Set-IncrementNumbers -State $state
        $taking = Get-CurrentIncrement -State $state
        Add-HistoryEntry -State $state -Action 'defer-increment' `
            -Detail "Deferred '$($current.scope)' to position $To; started '$($taking.scope)'."
        Save-WorkflowState -State $state -Path $workflowPath
        Show-WorkflowStatus -State $state
    }

    # Drops work the user has decided against. Completed increments are history
    # and stay; only planned work, or an active increment nothing was built for,
    # can leave the plan.
    'remove-increment' {
        $state = Get-WorkflowState -Path $workflowPath
        Assert-WorkflowBranch -State $state
        if (-not $PSBoundParameters.ContainsKey('Number')) {
            throw '-Number is required for remove-increment.'
        }
        $increments = [Collections.ArrayList]@(@($state.increments))
        if ($Number -lt 1 -or $Number -gt $increments.Count) {
            throw "Increment positions must be between 1 and $($increments.Count)."
        }
        $increment = $increments[$Number - 1]
        if ($increment.status -eq 'completed') {
            throw 'A completed increment is delivered history and cannot be removed.'
        }
        $isActive = $increment.id -eq $state.currentIncrementId
        if ($increment.status -ne 'planned' -and -not $isActive) {
            throw "Increment $Number is not planned and not the active increment."
        }
        if ($isActive) {
            if ($state.phase -ne 'BUILD') {
                throw "Removing the active increment is only available in BUILD, not '$($state.phase)'."
            }
            # Same evidence rule as defer-increment: a clean tree shows nothing
            # was built. Work already committed under it is invisible here.
            $changes = @(git status --porcelain -- . ':(exclude).progress')
            if ($changes.Count -gt 0) {
                throw 'The working tree must be clean, apart from .progress, to remove the active increment.'
            }
        }

        $increments.RemoveAt($Number - 1)
        $state.increments = @($increments)
        if ($isActive) {
            $state.currentIncrementId = $null
            if (@($state.increments).Where({ $_.status -eq 'planned' }).Count -gt 0) {
                Start-NextIncrement -State $state
            }
            else {
                # Nothing left to build: the branch is ready for its review.
                $state.phase = 'SUMMARY'
            }
        }
        Set-IncrementNumbers -State $state
        Add-HistoryEntry -State $state -Action 'remove-increment' `
            -Detail "Removed increment ${Number}: $($increment.scope)."
        Save-WorkflowState -State $state -Path $workflowPath
        Show-WorkflowStatus -State $state
    }

    'advance' {
        $state = Get-WorkflowState -Path $workflowPath
        Assert-WorkflowBranch -State $state
        $previousPhase = $state.phase
        switch ($state.phase) {
            'INTAKE' {
                if (@(Get-WorkflowRequest -State $state).Count -eq 0) {
                    throw 'Record at least one request before leaving INTAKE.'
                }
                if (-not (Test-RequirementsComplete -State $state)) {
                    throw ('Distil the requests into goal, constraints, done, and outOfScope ' +
                        'with set-requirement before leaving INTAKE.')
                }
                # Quick advances freely, as its predecessor START did: a small
                # self-contained pass does not earn a gate of its own. Detailed
                # Auto does not skip this one — autonomy is worth nothing if it
                # runs on a half-stated ask.
                if ($state.flow -ne 'Quick') {
                    Assert-Approval -State $state -GateName 'intake'
                }
                $state.phase = 'DESIGN'
            }
            'DESIGN' {
                if ($state.flow -eq 'Quick') {
                    Assert-Approval -State $state -GateName 'implement'
                    $state.phase = 'BUILD'
                }
                else {
                    $state.phase = 'SPLIT'
                }
            }
            'SPLIT' {
                if (@($state.increments).Count -eq 0) {
                    throw 'Add at least one increment before leaving SPLIT.'
                }
                # Every flow buys its first written line with this approval,
                # Detailed Auto included: the plan it will execute unattended is
                # exactly the plan the user should have seen.
                Assert-Approval -State $state -GateName 'implement'
                $state.phase = 'BRANCH'
            }
            'BRANCH' {
                $branch = (git branch --show-current).Trim()
                if ([string]::IsNullOrWhiteSpace($branch)) {
                    throw 'Switch from detached HEAD to a feature branch before leaving BRANCH.'
                }
                if ($branch -eq $state.baseBranch) {
                    throw "Create and switch to a feature branch before leaving BRANCH."
                }
                $state.featureBranch = $branch
                Start-NextIncrement -State $state
            }
            'BUILD' {
                $state.phase = 'VERIFY'
            }
            'VERIFY' {
                if ($state.flow -ne 'DetailedAuto') {
                    Assert-Approval -State $state -GateName 'verify'
                }
                $current = Get-CurrentIncrement -State $state
                if ($current) {
                    $current.status = 'verified'
                }
                $state.commitBaseline = Get-GitHead
                $state.phase = 'COMMIT'
            }
            'COMMIT' {
                if ($state.flow -eq 'Quick') {
                    throw 'Run finish, then commit the Quick workflow result.'
                }
                Assert-IncrementCommitted -State $state
                $current = Get-CurrentIncrement -State $state
                $current.status = 'completed'
                $state.commitBaseline = $null
                if (@($state.increments).Where({ $_.status -eq 'planned' }).Count -gt 0) {
                    Start-NextIncrement -State $state
                }
                else {
                    $state.currentIncrementId = $null
                    $state.phase = 'SUMMARY'
                }
            }
            'SUMMARY' {
                if ($state.flow -eq 'DetailedAuto') {
                    $state.phase = 'FINAL_REVIEW'
                }
                else {
                    Assert-Approval -State $state -GateName 'integrate'
                    $state.phase = 'INTEGRATE'
                }
            }
            'FINAL_REVIEW' {
                Assert-Approval -State $state -GateName 'integrate'
                $state.phase = 'INTEGRATE'
            }
            default {
                throw "Phase $($state.phase) cannot advance."
            }
        }
        Add-HistoryEntry -State $state -Action 'advance' -Detail "Advanced from $previousPhase to $($state.phase)."
        Save-WorkflowState -State $state -Path $workflowPath
        Show-WorkflowStatus -State $state
    }

    'return-to-build' {
        $state = Get-WorkflowState -Path $workflowPath
        Assert-WorkflowBranch -State $state
        if ($state.phase -ne 'VERIFY') {
            throw "Workflow can only return to BUILD from VERIFY; current phase is $($state.phase)."
        }
        $state.phase = 'BUILD'
        $state.approvals = @($state.approvals).Where({
            $_.gate -ne 'verify' -or $_.incrementId -ne $state.currentIncrementId
        })
        Add-HistoryEntry -State $state -Action 'return-to-build' -Detail 'Returned from VERIFY to BUILD.'
        Save-WorkflowState -State $state -Path $workflowPath
        Show-WorkflowStatus -State $state
    }

    'finish' {
        $state = Get-WorkflowState -Path $workflowPath
        Assert-WorkflowBranch -State $state
        $allowed = ($state.flow -eq 'Quick' -and $state.phase -eq 'COMMIT') -or
            ($state.flow -ne 'Quick' -and $state.phase -eq 'INTEGRATE')
        if (-not $allowed) {
            throw "Workflow state can only be removed at Quick/COMMIT or Detailed/INTEGRATE; current state is $($state.flow)/$($state.phase)."
        }
        Remove-Item -LiteralPath $workflowPath
        $progressMarkdownPath = Get-ProgressMarkdownPath -WorkflowPath $workflowPath
        if (Test-Path -LiteralPath $progressMarkdownPath) {
            Remove-Item -LiteralPath $progressMarkdownPath
        }
        $directory = Split-Path -Parent $workflowPath
        if ((Get-ChildItem -Force -LiteralPath $directory | Measure-Object).Count -eq 0) {
            Remove-Item -LiteralPath $directory
        }
        Write-Output 'Workflow state removed. Commit the deletion, then run dev-workflow-clean-branch before integration.'
        Show-WorkflowStatus -State $state -Status finished
    }
}
}
finally {
    if ($workflowLock) {
        Exit-WorkflowLock -Lock $workflowLock
    }
}
