#Requires -Version 7
<#
  Diagnoses why an agent is not following the policy in a given repository.

  Layer 1 (machine) is delegated to agents-install's verify-agents.ps1, which
  already owns the managed blocks and junctions. Layer 2 (repository) is checked
  here: whether this repository reaches the policy at all, by submodule or by a
  root instruction file, and whether an opt-in trigger is present. Layer 3 --
  whether a bot actually loaded what is wired -- cannot be observed from disk
  and is left to the skill's own procedure.

  Prints a Markdown result table and exits non-zero when any check fails.
#>
param(
    [string]$RepositoryPath = (Get-Location).Path,
    [string]$AgentsRoot,
    [string[]]$Tools,
    [switch]$SkipInstallCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    <# Records one check outcome for the summary table. #>
    param(
        [Parameter(Mandatory)][string]$Scope,
        [Parameter(Mandatory)][string]$Check,
        [Parameter(Mandatory)][ValidateSet('pass', 'fail', 'warn', 'info')][string]$Status,
        [string]$Detail = ''
    )
    $results.Add([pscustomobject]@{ Scope = $Scope; Check = $Check; Status = $Status; Detail = $Detail })
}

if (-not (Test-Path -LiteralPath $RepositoryPath)) {
    throw "Repository path '$RepositoryPath' does not exist."
}
$repo = (Resolve-Path -LiteralPath $RepositoryPath).ProviderPath.TrimEnd('\', '/')

# --- Repository identity ---
$gitRoot = & git -C $repo rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -eq 0 -and $gitRoot) {
    $gitRoot = ([System.IO.Path]::GetFullPath(("$gitRoot" -replace '/', [System.IO.Path]::DirectorySeparatorChar))).TrimEnd('\', '/')
    if ($gitRoot -ne $repo) {
        # Instruction files are read from the repository root, not the subdirectory.
        Add-Result -Scope 'repo' -Check 'root' -Status 'info' -Detail "checking repository root $gitRoot (invoked from $repo)"
        $repo = $gitRoot
    }
    else {
        Add-Result -Scope 'repo' -Check 'root' -Status 'info' -Detail $repo
    }
}
else {
    Add-Result -Scope 'repo' -Check 'root' -Status 'warn' -Detail "$repo is not a git repository; a flow cannot branch or commit here"
}

# The agents clone is its own policy: it needs no reference and no submodule.
$isAgentsClone = (Test-Path -LiteralPath (Join-Path $repo 'AGENTS.md')) -and
                 (Test-Path -LiteralPath (Join-Path $repo 'skills\agents-install\SKILL.md'))

# --- How this repository reaches the policy ---
$rootInstructions = @('AGENTS.md', 'CLAUDE.md') |
    ForEach-Object { Join-Path $repo $_ } |
    Where-Object { Test-Path -LiteralPath $_ }

$submodulePolicy = Join-Path $repo 'agents\AGENTS.md'
$hasSubmodulePolicy = Test-Path -LiteralPath $submodulePolicy

# A reference is any mention of the policy file, by submodule path or absolute path.
$referencingFiles = @()
foreach ($file in $rootInstructions) {
    $content = Get-Content -LiteralPath $file -Raw
    if ($null -eq $content) { continue }
    if ($content -match 'agents[\\/]AGENTS\.md') {
        $referencingFiles += (Split-Path -Leaf $file)
    }
}

if ($isAgentsClone) {
    Add-Result -Scope 'repo' -Check 'instructions' -Status 'pass' -Detail 'this is the agents clone; its own AGENTS.md is the policy'
}
elseif (-not $rootInstructions) {
    Add-Result -Scope 'repo' -Check 'instructions' -Status 'fail' -Detail 'no root AGENTS.md or CLAUDE.md; nothing tells a tool this repository opts in'
}
elseif (-not $referencingFiles) {
    $names = ($rootInstructions | ForEach-Object { Split-Path -Leaf $_ }) -join ', '
    Add-Result -Scope 'repo' -Check 'instructions' -Status 'fail' -Detail "$names exist but none references agents/AGENTS.md"
}
else {
    Add-Result -Scope 'repo' -Check 'instructions' -Status 'pass' -Detail "$($referencingFiles -join ', ') reference the policy"
}

# Claude Code reads CLAUDE.md; the other tools read AGENTS.md. One without the
# other is the classic "works in one tool, ignored in another" case.
$hasAgentsMd = Test-Path -LiteralPath (Join-Path $repo 'AGENTS.md')
$hasClaudeMd = Test-Path -LiteralPath (Join-Path $repo 'CLAUDE.md')
if ($isAgentsClone) {
    # Nothing embeds the clone, so it needs no per-tool instruction file of its own.
}
elseif ($hasAgentsMd -and -not $hasClaudeMd) {
    Add-Result -Scope 'repo' -Check 'per-tool' -Status 'warn' -Detail 'AGENTS.md only; Claude Code reads CLAUDE.md and will not see it from the repository'
}
elseif ($hasClaudeMd -and -not $hasAgentsMd) {
    Add-Result -Scope 'repo' -Check 'per-tool' -Status 'warn' -Detail 'CLAUDE.md only; Codex and opencode read AGENTS.md and will not see it from the repository'
}
elseif ($hasAgentsMd -and $hasClaudeMd) {
    Add-Result -Scope 'repo' -Check 'per-tool' -Status 'pass' -Detail 'AGENTS.md and CLAUDE.md both present'
}

# --- The referenced policy has to resolve to a real file ---
if ($isAgentsClone) {
    $ownSkills = @(Get-ChildItem -LiteralPath (Join-Path $repo 'skills') -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') }).Count
    Add-Result -Scope 'repo' -Check 'policy' -Status 'pass' -Detail "the clone's own AGENTS.md, $ownSkills skills"
}
elseif ($hasSubmodulePolicy) {
    $skillsDir = Join-Path $repo 'agents\skills'
    $skillCount = if (Test-Path -LiteralPath $skillsDir) {
        @(Get-ChildItem -LiteralPath $skillsDir -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') }).Count
    }
    else { 0 }

    if ($skillCount -gt 0) {
        Add-Result -Scope 'repo' -Check 'policy' -Status 'pass' -Detail "agents/AGENTS.md present, $skillCount skills"
    }
    else {
        Add-Result -Scope 'repo' -Check 'policy' -Status 'fail' -Detail 'agents/AGENTS.md present but agents/skills holds no SKILL.md'
    }
}
elseif (Test-Path -LiteralPath (Join-Path $repo 'agents')) {
    # An uninitialised submodule is an empty directory: the reference dangles.
    Add-Result -Scope 'repo' -Check 'policy' -Status 'fail' -Detail 'agents/ exists but has no AGENTS.md; run git submodule update --init --recursive'
}
elseif ($referencingFiles) {
    Add-Result -Scope 'repo' -Check 'policy' -Status 'fail' -Detail 'root instructions reference agents/AGENTS.md but no agents/ directory exists'
}
else {
    Add-Result -Scope 'repo' -Check 'policy' -Status 'info' -Detail 'no agents/ submodule; the policy must come from a global install'
}

# --- Commit scopes, which git-commit's checker requires ---
if ($rootInstructions) {
    $scopeSource = @($rootInstructions | Where-Object {
        $c = Get-Content -LiteralPath $_ -Raw
        $c -and $c -match '(?m)^##\s+Commit scopes\s*$'
    })
    if ($scopeSource) {
        $names = ($scopeSource | ForEach-Object { Split-Path -Leaf $_ }) -join ', '
        Add-Result -Scope 'repo' -Check 'commit-scopes' -Status 'pass' -Detail "declared in $names"
    }
    else {
        Add-Result -Scope 'repo' -Check 'commit-scopes' -Status 'warn' -Detail 'no "## Commit scopes" section; git-commit will reject every scoped subject'
    }
}

# --- Live workflow state ---
$workflowState = Join-Path $repo '.progress\workflow.json'
$hasWorkflowState = Test-Path -LiteralPath $workflowState
if ($hasWorkflowState) {
    $phase = try {
        $json = Get-Content -LiteralPath $workflowState -Raw | ConvertFrom-Json
        $flow = if ($json.PSObject.Properties.Name -contains 'flow') { $json.flow } else { '?' }
        $ph = if ($json.PSObject.Properties.Name -contains 'phase') { $json.phase } else { '?' }
        "$flow at $ph"
    }
    catch { 'unreadable JSON' }
    Add-Result -Scope 'repo' -Check 'workflow-state' -Status 'pass' -Detail ".progress/workflow.json present ($phase); this repository opts in on its own"
}
else {
    Add-Result -Scope 'repo' -Check 'workflow-state' -Status 'info' -Detail 'no .progress/workflow.json; no flow in progress'
}

# --- Machine-side install, delegated ---
if ($SkipInstallCheck) {
    Add-Result -Scope 'install' -Check 'verify' -Status 'info' -Detail 'skipped by -SkipInstallCheck'
}
else {
    $verify = Join-Path $PSScriptRoot '..\..\agents-install\scripts\verify-agents.ps1'
    if (-not (Test-Path -LiteralPath $verify)) {
        Add-Result -Scope 'install' -Check 'verify' -Status 'warn' -Detail 'agents-install/scripts/verify-agents.ps1 not found next to this skill'
    }
    else {
        $arguments = @{}
        if ($AgentsRoot) { $arguments['AgentsRoot'] = $AgentsRoot }
        if ($Tools) { $arguments['Tools'] = $Tools }
        $output = & $verify @arguments 2>&1
        $installFailed = $LASTEXITCODE -ne 0

        # Re-emit the verifier's own rows so one table answers the whole question.
        foreach ($line in $output) {
            $text = "$line"
            if ($text -notmatch '^\|') { continue }
            if ($text -match '^\|\s*Scope\s*\|' -or $text -match '^\|\s*-{2,}') { continue }
            $cells = $text.Trim('|').Split('|')
            if ($cells.Count -lt 4) { continue }
            $status = $cells[2].Trim()
            if ($status -notin @('pass', 'fail', 'warn', 'info')) { $status = 'info' }
            Add-Result -Scope "install/$($cells[0].Trim())" -Check $cells[1].Trim() -Status $status -Detail $cells[3].Trim()
        }

        if ($installFailed -and -not @($results | Where-Object { $_.Scope -like 'install/*' -and $_.Status -eq 'fail' })) {
            Add-Result -Scope 'install' -Check 'verify' -Status 'fail' -Detail 'verify-agents.ps1 exited non-zero; run it directly for the reason'
        }
    }
}

# --- Reachability verdict, the question the user actually asked ---
$installBroken = [bool]@($results | Where-Object { $_.Scope -like 'install/*' -and $_.Status -eq 'fail' })
$repoPolicyBroken = [bool]@($results | Where-Object { $_.Scope -eq 'repo' -and $_.Check -eq 'policy' -and $_.Status -eq 'fail' })
# A repository that names its own policy is not rescued by the global install:
# the tool follows the nearer reference, and a dangling one silences everything.
$policyReachable = if ($isAgentsClone -or $hasSubmodulePolicy) { $true }
    elseif ($repoPolicyBroken) { $false }
    else { -not $installBroken }
$optedIn = $isAgentsClone -or ([bool]$referencingFiles) -or $hasWorkflowState

if ($optedIn -and $policyReachable) {
    Add-Result -Scope 'verdict' -Check 'pickup' -Status 'pass' -Detail 'wiring is correct; if the agent still ignores the policy the cause is pickup, not installation'
}
elseif (-not $optedIn) {
    # Silence here is the guard working, not a fault; it is a fault only if the
    # user expected this repository to be opted in.
    Add-Result -Scope 'verdict' -Check 'pickup' -Status 'info' -Detail 'this repository does not opt in, so the policy is deliberately silent here; wire it only if it should be governed'
}
else {
    Add-Result -Scope 'verdict' -Check 'pickup' -Status 'fail' -Detail 'this repository opts in but the policy it points at does not resolve; the agent sees a dangling reference and ignores it'
}

# --- Report ---
Write-Output '| Scope | Check | Status | Detail |'
Write-Output '| --- | --- | --- | --- |'
foreach ($r in $results) {
    Write-Output "| $($r.Scope) | $($r.Check) | $($r.Status) | $($r.Detail) |"
}
Write-Output ''

$failed = @($results | Where-Object Status -eq 'fail')
$warned = @($results | Where-Object Status -eq 'warn')
if ($failed) {
    Write-Output "$($failed.Count) check(s) failed, $($warned.Count) warning(s)."
    exit 1
}
Write-Output "All checks passed, $($warned.Count) warning(s)."
