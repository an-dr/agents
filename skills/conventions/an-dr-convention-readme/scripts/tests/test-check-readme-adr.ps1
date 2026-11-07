#Requires -Version 7
<# Checks that check-readme.ps1 finds ADRs in docs/adr, the folder an-dr-convention-adr writes them to. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Join-Path ([IO.Path]::GetTempPath()) "check-readme-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path (Join-Path $root 'docs/adr') -Force | Out-Null
$script = Join-Path $PSScriptRoot '../check-readme.ps1'
# The Markdown format check is not under test; an empty folder makes check-readme skip it.
$markdown = Join-Path $root 'no-markdown-skill'
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
try {
    Set-Content -LiteralPath (Join-Path $root 'docs/adr/ADR-001-a.md') -Value '# ADR-001: A'
    Set-Content -LiteralPath (Join-Path $root 'README.md') -Value "# Sample`n`nA tool."
    $output = (& pwsh -NoProfile -NonInteractive -File $script -Path $root -MarkdownSkill $markdown 2>&1) -join "`n"
    Assert ($output -match 'docs directory\s+yes, with ADRs') "docs/adr was not recognised:`n$output"
    Assert ($output -match 'module\.adr') "The unlinked-ADR note is missing:`n$output"
    Write-Output 'README ADR detection checks passed.'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force
}
