#Requires -Version 7
<#
    Composes, validates, and records a commit in one call.
    Nothing is committed unless the assembled message passes every rule.
#>
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory)][string]$Type,
    [string]$Scope,
    [Parameter(Mandatory)][string]$Summary,
    [string]$Footer,
    [switch]$Breaking,
    [switch]$Amend,
    [switch]$DryRun,
    # Body entries follow the named parameters, one quoted argument each,
    # written without the '- ' marker so PowerShell cannot read them as flags.
    [Parameter(ValueFromRemainingArguments)][string[]]$Entry
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'GitCommit.Format.psm1') -Force

$subject = $Type
if ($Scope) { $subject += "($Scope)" }
if ($Breaking) { $subject += '!' }
$subject += ": $Summary"

$parts = [System.Collections.Generic.List[string]]::new()
$parts.Add($subject)

$entries = @(@($Entry) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        $text = $_.Trim()
        if ($text -cmatch '^- ') { $text } else { "- $text" }
    })
if ($entries.Count -gt 0) {
    $parts.Add('')
    foreach ($line in $entries) { $parts.Add($line) }
}

$footers = @(
    (($Footer -replace "`r`n", "`n") -split "`n") |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
)
if ($Breaking -and -not ($footers | Where-Object { $_ -cmatch '^BREAKING CHANGE: ' })) {
    throw 'A breaking change needs a -Footer "BREAKING CHANGE: <consequence>".'
}
if ($footers.Count -gt 0) {
    $parts.Add('')
    foreach ($line in $footers) { $parts.Add($line.Trim()) }
}

$message = ($parts -join "`n") + "`n"

$violations = @(Get-CommitMessageViolation -Message $message -AllowedScope (Get-DeclaredScope))
Write-CommitViolation -Violation $violations -Label 'Commit message check:'
Write-Output $message
if ((Measure-CommitError -Violation $violations) -gt 0) {
    Write-Output 'The message breaks the format; nothing was committed.'
    exit 1
}
if ($DryRun) {
    Write-Output 'Dry run: nothing was committed.'
    return
}

$staged = @(& git diff --cached --name-only)
if ($LASTEXITCODE -ne 0) { throw 'git diff --cached failed. See Git output above.' }
if ($staged.Count -eq 0 -and -not $Amend) {
    throw 'Nothing is staged. Stage the change first.'
}

$messagePath = [IO.Path]::GetTempFileName()
try {
    [IO.File]::WriteAllText($messagePath, $message, [Text.UTF8Encoding]::new($false))
    $arguments = @('commit', '-F', $messagePath)
    if ($Amend) { $arguments += '--amend' }
    & git @arguments
    if ($LASTEXITCODE -ne 0) { throw 'git commit failed. See Git output above.' }
}
finally {
    Remove-Item -Force -LiteralPath $messagePath -ErrorAction SilentlyContinue
}
