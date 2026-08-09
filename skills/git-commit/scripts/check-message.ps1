#Requires -Version 7
<#
    Validates an existing commit message file, string, or commit.
    Suitable as a commit-msg hook: it exits non-zero on any rule violation.
#>
[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Path')][string]$Path,
    [Parameter(Mandatory, ParameterSetName = 'Message')][string]$Message,
    [Parameter(Mandatory, ParameterSetName = 'Commit')][string]$Commit
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'GitCommit.Format.psm1') -Force

$text = switch ($PSCmdlet.ParameterSetName) {
    'Path' {
        if (-not (Test-Path -LiteralPath $Path)) { throw "Message file '$Path' does not exist." }
        [IO.File]::ReadAllText($Path)
    }
    'Message' { $Message }
    'Commit' {
        $output = @(& git show -s --format=%B $Commit)
        if ($LASTEXITCODE -ne 0) { throw "git show failed for '$Commit'. See Git output above." }
        $output -join "`n"
    }
}

$violations = @(Get-CommitMessageViolation -Message $text -AllowedScope (Get-DeclaredScope))
Write-CommitViolation -Violation $violations -Label 'Commit message check:'
$errorCount = Measure-CommitError -Violation $violations
if ($errorCount -gt 0) {
    Write-Output "The message breaks $errorCount rule(s)."
    exit 1
}
Write-Output 'The commit message matches the format.'
