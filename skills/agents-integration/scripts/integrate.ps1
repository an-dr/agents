#Requires -Version 7
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or -not $root) {
    throw 'Run this script inside a Git repository.'
}
$root = $root.Trim()

$agentsUrl = 'https://github.com/an-dr/agents.git'
$agentsPath = Join-Path $root 'agents'
$agentsMdPath = Join-Path $root 'AGENTS.md'
$claudeMdPath = Join-Path $root 'CLAUDE.md'
$sectionMarker = '## Primary instructions'
$scopeMarker = '## Commit scopes'

$commitScopes = @'
## Commit scopes

Scopes the `git-commit` skill accepts. One per component; add a scope before
using it, and leave it out of a commit that is genuinely cross-cutting.

<!-- - launcher -->
'@

$primaryInstructions = @'
## Primary instructions

- Use `agents/AGENTS.md` as the base instruction
- Use `AGENTS.md` in the repo root and in the subfolders as scoped extensions of the base rules
- Priority (later entries extend or overwrite earlier ones):
  1. `REPO/agents/AGENTS.md` — base
  2. `REPO/AGENTS.md` — this file
  3. `REPO/**/AGENTS.md` — any subdirectory AGENTS.md, chained by depth
'@

$freshAgentsMd = @'
# Agent Context

Notes for AI agents working on this repo that cannot be deduced from the code alone.

## Primary instructions

- Use `agents/AGENTS.md` as the base instruction
- Use `AGENTS.md` in the repo root and in the subfolders as scoped extensions of the base rules
- Priority (later entries extend or overwrite earlier ones):
  1. `REPO/agents/AGENTS.md` — base
  2. `REPO/AGENTS.md` — this file
  3. `REPO/**/AGENTS.md` — any subdirectory AGENTS.md, chained by depth

## Project

<!-- Describe what this repo is, for an agent with no other context. -->

## Commit scopes

Scopes the `git-commit` skill accepts. One per component; add a scope before
using it, and leave it out of a commit that is genuinely cross-cutting.

<!-- - launcher -->
'@

$claudeMdTemplate = @'
# CLAUDE.md

**Before every task:** Read `agents/AGENTS.md` and `AGENTS.md`.
Open your response by stating the active flow and phase — or that no flow
applies (pure question/analysis, or edits to the agents repo itself) — and why.

`agents/AGENTS.md` is the base instruction set; the root `AGENTS.md` extends it
with repo-specific context.
'@

# 1. agents/ submodule
if (Test-Path -LiteralPath $agentsPath) {
    Write-Output "agents/ already exists -- left as-is."
}
else {
    Push-Location $root
    try {
        git submodule add $agentsUrl agents
        if ($LASTEXITCODE -ne 0) { throw 'git submodule add failed.' }
    }
    finally {
        Pop-Location
    }
    Write-Output "Added agents/ as a git submodule ($agentsUrl)."
}

# 2. Root AGENTS.md
if (-not (Test-Path -LiteralPath $agentsMdPath)) {
    Set-Content -LiteralPath $agentsMdPath -Value $freshAgentsMd -NoNewline -Encoding utf8
    Write-Output "Created $agentsMdPath."
}
else {
    $existing = Get-Content -LiteralPath $agentsMdPath -Raw
    if ($existing -notlike "*$sectionMarker*") {
        $existing = $primaryInstructions + "`n`n" + $existing.TrimStart()
        Write-Output "Inserted the Primary instructions section into $agentsMdPath."
    }
    else {
        Write-Output "$agentsMdPath already has a Primary instructions section -- left as-is."
    }
    if ($existing -notlike "*$scopeMarker*") {
        $existing = $existing.TrimEnd() + "`n`n" + $commitScopes + "`n"
        Write-Output "Appended the Commit scopes section to $agentsMdPath."
    }
    else {
        Write-Output "$agentsMdPath already has a Commit scopes section -- left as-is."
    }
    Set-Content -LiteralPath $agentsMdPath -Value $existing -NoNewline -Encoding utf8
}

# 3. Root CLAUDE.md
if (-not (Test-Path -LiteralPath $claudeMdPath)) {
    Set-Content -LiteralPath $claudeMdPath -Value $claudeMdTemplate -NoNewline -Encoding utf8
    Write-Output "Created $claudeMdPath."
}
else {
    Write-Output "$claudeMdPath already exists -- left as-is."
}
