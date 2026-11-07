#Requires -Version 7
<# Checks size-diff.ps1 on a scratch repository: changed files, new files, and the always-loaded total. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Join-Path ([IO.Path]::GetTempPath()) "size-diff-$([guid]::NewGuid().ToString('N'))"
$skill = Join-Path $root 'skills/actions/an-dr-example'
New-Item -ItemType Directory -Path $skill -Force | Out-Null
$script = Join-Path $PSScriptRoot '../size-diff.ps1'
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
try {
    # 40 characters each, so 10 tokens; the em dash checks that git output is read as UTF-8.
    Set-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Value ('a' * 39 + '—') -NoNewline
    Set-Content -LiteralPath (Join-Path $skill 'SKILL.md') -Value "---`ndescription: $('d' * 40)`n---`n" -NoNewline
    & git -C $root init --quiet
    & git -C $root -c core.autocrlf=false add -A
    & git -C $root -c user.name=test -c user.email=test@example.invalid commit --quiet -m baseline

    Set-Content -LiteralPath (Join-Path $root 'AGENTS.md') -Value ('a' * 79 + '—') -NoNewline
    New-Item -ItemType Directory -Path (Join-Path $skill 'references') | Out-Null
    Set-Content -LiteralPath (Join-Path $skill 'references/mode.md') -Value ('r' * 80) -NoNewline
    $output = (& pwsh -NoProfile -NonInteractive -File $script -Root $root 2>&1) -join "`n"
    Assert ($LASTEXITCODE -eq 0) "The report failed.`n$output"
    Assert ($output -match '\| `AGENTS\.md` \| 10 \| 20 \| \+10 \|') "AGENTS.md row is wrong.`n$output"
    Assert ($output -match '\| `skills/actions/an-dr-example/references/mode\.md` \| 0 \| 20 \| \+20 \|') "The new reference file is missing.`n$output"
    Assert ($output -notmatch 'an-dr-example/SKILL\.md') "An unchanged SKILL.md was listed.`n$output"
    Assert ($output -match '\| always loaded \| 20 \| 30 \| \+10 \|') "The always-loaded total is wrong.`n$output"
    Write-Output 'Size report checks passed.'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force
}
