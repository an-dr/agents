#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory)]
    [ValidateSet('start', 'status', 'advance', 'approve', 'add-increment', 'move-increment', 'finish')]
    [string]$Command,

    [ValidateSet('Detailed', 'DetailedAuto', 'Quick')]
    [string]$Flow,
    [string]$Goal,
    [string]$Constraints,
    [string]$Done,
    [string]$OutOfScope,
    [ValidateSet('requirements', 'design', 'verify', 'mr', 'merge', 'final')]
    [string]$Gate,
    [string]$Note,
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

function Assert-WorkflowState {
    param([Parameter(Mandatory)]$State)

    if ($State.schemaVersion -ne 1) {
        throw "Unsupported workflow schema version '$($State.schemaVersion)'."
    }
    if ($State.flow -notin @('Quick', 'Detailed', 'DetailedAuto')) {
        throw "Unsupported workflow flow '$($State.flow)'."
    }
    $validPhases = if ($State.flow -eq 'Quick') {
        @('START', 'DESIGN', 'BUILD', 'VERIFY', 'COMMIT')
    }
    elseif ($State.flow -eq 'Detailed') {
        @('START', 'DESIGN', 'SPLIT', 'BRANCH', 'BUILD', 'VERIFY', 'COMMIT', 'MR', 'MERGE_READY', 'MERGE')
    }
    else {
        @('START', 'DESIGN', 'SPLIT', 'BRANCH', 'BUILD', 'VERIFY', 'COMMIT', 'MR', 'FINAL_REVIEW', 'MERGE')
    }
    if ($State.phase -notin $validPhases) {
        throw "Phase '$($State.phase)' is invalid for flow '$($State.flow)'."
    }
    foreach ($property in @('baseBranch', 'baseCommit', 'createdAt', 'updatedAt')) {
        if ([string]::IsNullOrWhiteSpace([string]$State.$property)) {
            throw "Workflow state is missing '$property'."
        }
    }
    foreach ($property in @('goal', 'constraints', 'done', 'outOfScope')) {
        if ([string]::IsNullOrWhiteSpace([string]$State.requirements.$property)) {
            throw "Workflow requirements are missing '$property'."
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
    if ($State.flow -ne 'Quick' -and $State.phase -in @('MR', 'MERGE_READY', 'FINAL_REVIEW', 'MERGE') -and
        @($increments | Where-Object { $_.status -ne 'completed' }).Count -gt 0) {
        throw "Phase '$($State.phase)' requires every increment to be completed."
    }
    if ($State.flow -ne 'Quick' -and $State.phase -notin @('START', 'DESIGN', 'SPLIT', 'BRANCH') -and
        [string]::IsNullOrWhiteSpace([string]$State.featureBranch)) {
        throw "Phase '$($State.phase)' requires featureBranch."
    }

    foreach ($approval in @($State.approvals)) {
        if ($approval.gate -notin @('requirements', 'design', 'verify', 'mr', 'merge', 'final') -or
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
    param([Parameter(Mandatory)]$State)

    $flowLabel = if ($State.flow -eq 'DetailedAuto') { 'Detailed Auto' } else { $State.flow }
    $increment = Get-CurrentIncrement -State $State
    Write-Output "Flow: $flowLabel"
    Write-Output "Phase: $($State.phase)"
    if ($increment) {
        Write-Output "Increment: $($increment.number) of $(@($State.increments).Count) — $($increment.scope)"
    }
    elseif (@($State.increments).Count -gt 0) {
        Write-Output "Increments: $(@($State.increments).Count)"
    }
    foreach ($item in @($State.increments)) {
        Write-Output "  $($item.number) [$($item.status)] $($item.scope) — $($item.description)"
    }
    Write-Output "Goal: $($State.requirements.goal)"
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
        foreach ($requiredValue in @{
                Flow = $Flow; Goal = $Goal; Constraints = $Constraints;
                Done = $Done; OutOfScope = $OutOfScope
            }.GetEnumerator()) {
            if ([string]::IsNullOrWhiteSpace([string]$requiredValue.Value)) {
                throw "-$($requiredValue.Key) is required when starting a workflow."
            }
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
            phase              = 'START'
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
        $expected = switch ($state.phase) {
            'START' { 'requirements' }
            'DESIGN' { 'design' }
            'VERIFY' { 'verify' }
            'MR' { 'mr' }
            'MERGE_READY' { 'merge' }
            'FINAL_REVIEW' { 'final' }
            default { $null }
        }
        if ($state.flow -eq 'DetailedAuto' -and $state.phase -ne 'FINAL_REVIEW') {
            throw 'Detailed Auto accepts user approval only at FINAL_REVIEW.'
        }
        if ($Gate -ne $expected) {
            throw "Gate '$Gate' is not valid during $($state.phase). Expected '$expected'."
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

    'add-increment' {
        $state = Get-WorkflowState -Path $workflowPath
        Assert-WorkflowBranch -State $state
        if ($state.flow -eq 'Quick') {
            throw 'Quick workflows do not use increments.'
        }
        if ([string]::IsNullOrWhiteSpace($Scope) -or [string]::IsNullOrWhiteSpace($Description)) {
            throw '-Scope and -Description are required for add-increment.'
        }
        if ($state.phase -eq 'MERGE') {
            throw 'The approved workflow is ready to merge. Start a follow-up workflow for new scope.'
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
        if ($state.phase -in @('MR', 'MERGE_READY', 'FINAL_REVIEW')) {
            $state.phase = 'SPLIT'
            $state.approvals = @($state.approvals).Where({ $_.gate -notin @('mr', 'merge', 'final') })
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

    'advance' {
        $state = Get-WorkflowState -Path $workflowPath
        Assert-WorkflowBranch -State $state
        $previousPhase = $state.phase
        switch ($state.phase) {
            'START' {
                if ($state.flow -ne 'DetailedAuto') {
                    Assert-Approval -State $state -GateName 'requirements'
                }
                $state.phase = 'DESIGN'
            }
            'DESIGN' {
                if ($state.flow -ne 'DetailedAuto') {
                    Assert-Approval -State $state -GateName 'design'
                }
                $state.phase = if ($state.flow -eq 'Quick') { 'BUILD' } else { 'SPLIT' }
            }
            'SPLIT' {
                if (@($state.increments).Count -eq 0) {
                    throw 'Add at least one increment before leaving SPLIT.'
                }
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
                    $state.phase = 'MR'
                }
            }
            'MR' {
                if ($state.flow -eq 'DetailedAuto') {
                    $state.phase = 'FINAL_REVIEW'
                }
                else {
                    Assert-Approval -State $state -GateName 'mr'
                    $state.phase = 'MERGE_READY'
                }
            }
            'MERGE_READY' {
                Assert-Approval -State $state -GateName 'merge'
                $state.phase = 'MERGE'
            }
            'FINAL_REVIEW' {
                Assert-Approval -State $state -GateName 'final'
                $state.phase = 'MERGE'
            }
            default {
                throw "Phase $($state.phase) cannot advance."
            }
        }
        Add-HistoryEntry -State $state -Action 'advance' -Detail "Advanced from $previousPhase to $($state.phase)."
        Save-WorkflowState -State $state -Path $workflowPath
        Show-WorkflowStatus -State $state
    }

    'finish' {
        $state = Get-WorkflowState -Path $workflowPath
        Assert-WorkflowBranch -State $state
        $allowed = ($state.flow -eq 'Quick' -and $state.phase -eq 'COMMIT') -or
            ($state.flow -ne 'Quick' -and $state.phase -eq 'MERGE')
        if (-not $allowed) {
            throw "Workflow state can only be removed at Quick/COMMIT or Detailed/MERGE; current state is $($state.flow)/$($state.phase)."
        }
        Remove-Item -LiteralPath $workflowPath
        $directory = Split-Path -Parent $workflowPath
        if ((Get-ChildItem -Force -LiteralPath $directory | Measure-Object).Count -eq 0) {
            Remove-Item -LiteralPath $directory
        }
        Write-Output 'Workflow state removed. Commit this deletion with the final result before merging or sharing it.'
    }
}
}
finally {
    if ($workflowLock) {
        Exit-WorkflowLock -Lock $workflowLock
    }
}
