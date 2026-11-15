#Requires -Version 7
<#
    A work branch started from dev carries tmp-agent-wip.json and other
    tmp files: integration finds dev from the state, strips every tmp file from
    every commit, refuses to land while any remains, and lands on dev.
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scripts = Join-Path $PSScriptRoot '..'
$wipDataSkill = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' '..' 'an-dr-ai-use-wip-data')).Path
$failures = [Collections.Generic.List[string]]::new()
$root = Join-Path ([IO.Path]::GetTempPath()) ('integrate-tmp-' + [guid]::NewGuid().ToString('N'))
$origin = Join-Path $root 'origin.git'
$work = Join-Path $root 'work'

function Invoke-Step {
    param([string]$Script, [string[]]$Arguments = @())
    $output = @(& pwsh -NoProfile -NonInteractive -File (Join-Path $scripts $Script) @Arguments -WipDataSkill $wipDataSkill 2>&1)
    return [pscustomobject]@{ Code = $LASTEXITCODE; Output = ($output -join "`n") }
}

function Save-Commit {
    param([string]$Path, [string]$Content, [string]$Message)
    $full = Join-Path $work $Path
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $full) | Out-Null
    Set-Content -LiteralPath $full -Value $Content
    git add -f -- $Path
    git commit -q -m $Message
}

New-Item -ItemType Directory -Path $root | Out-Null
try {
    git init -q --bare -b main $origin
    git clone -q $origin $work 2>$null
    Push-Location $work
    git config user.email 'test@example.invalid'
    git config user.name 'Test'
    Save-Commit 'README.md' 'base' 'chore: initial'
    git push -q origin main
    git switch -q -c dev
    Save-Commit 'dev.txt' 'dev' 'chore: dev work'
    git push -q -u origin dev 2>$null
    git switch -q -c vibe/x
    Save-Commit 'tmp-agent-wip.json' '{ "schemaVersion": 1, "sections": { "workflow": { "flow": "Vibe", "baseBranch": "dev" } } }' 'chore: record workflow state'
    Save-Commit 'feature.txt' 'feature' 'feat: add the feature'
    Save-Commit 'docs/.tmp-ai-gen/report.html' 'r' 'chore: keep a report'
    Save-Commit 'src/tmp_buffer.txt' 'kept' 'feat: add a buffer that is not a tmp file'

    $check = Invoke-Step 'integrate-1-check.ps1'
    if ($check.Code -ne 0 -or $check.Output -notmatch 'Base branch: dev') { $failures.Add("The base was not read from the state: $($check.Output)") }
    if ($check.Output -notmatch 'tmp-agent-wip.json') { $failures.Add('The check did not list the tmp files.') }

    $early = Invoke-Step 'integrate-4-finish.ps1' @('-Mode', 'Commits')
    if ($early.Code -eq 0 -or $early.Output -notmatch 'still carries tmp files') { $failures.Add("finish landed tmp files: $($early.Output)") }

    $rebase = Invoke-Step 'integrate-3-rebase.ps1'
    if ($rebase.Code -ne 0) { $failures.Add("rebase failed: $($rebase.Output)") }
    $left = @(git log --format= --name-only dev..HEAD | Where-Object { $_ -match '(^|/)\.?tmp-' })
    if ($left.Count -gt 0) { $failures.Add("tmp files survived: $($left -join ', ')") }
    if (Test-Path 'tmp-agent-wip.json') { $failures.Add('The state file stayed on disk.') }
    if (-not (Test-Path 'src/tmp_buffer.txt')) { $failures.Add('A file that only contains tmp was stripped.') }
    $subjects = @(git log --format=%s dev..HEAD)
    if ($subjects -contains 'chore: record workflow state') { $failures.Add('A tmp-only commit was kept.') }
    if ($subjects -notcontains 'feat: add the feature') { $failures.Add('A real commit was lost.') }
    if ((git config --get branch.vibe/x.an-dr-base) -ne 'dev') { $failures.Add('The base was not recorded in the branch config.') }

    $finish = Invoke-Step 'integrate-4-finish.ps1' @('-Mode', 'Commits')
    if ($finish.Code -ne 0) { $failures.Add("finish failed: $($finish.Output)") }
    if ((git branch --show-current) -ne 'dev') { $failures.Add('The branch did not land on dev.') }
    if (-not (Test-Path 'feature.txt')) { $failures.Add('dev does not have the feature.') }
    if ((git rev-parse main) -eq (git rev-parse dev)) { $failures.Add('main moved.') }
}
finally {
    Pop-Location -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force -LiteralPath $root -ErrorAction SilentlyContinue
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Output "FAIL: $_" }
    exit 1
}
Write-Output 'Tmp-file checks passed: base from state, strip, refusal, landing on dev.'
