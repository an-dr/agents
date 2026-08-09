Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:CommitTypes = @(
    'feat', 'fix', 'docs', 'refactor', 'test',
    'style', 'chore', 'build', 'ci', 'perf', 'revert'
)
$script:SubjectMaxLength = 72
$script:EntryTargetLength = 72
$script:EntryMaxCount = 5
$script:FooterPattern = '^(BREAKING CHANGE|[A-Za-z][A-Za-z-]*): \S|^[A-Za-z][A-Za-z-]* #\S'
$script:MarkdownPattern = '`|\*\*|\]\(|^#{1,6} '
$script:AttributionPattern = 'co-authored-by|generated with|noreply@anthropic\.com'

function Get-CommitType {
    <# Returns the closed set of allowed commit types. #>
    return $script:CommitTypes
}

function New-CommitViolation {
    <# Builds one violation record. #>
    param(
        [Parameter(Mandatory)][ValidateSet('error', 'warning')][string]$Severity,
        [Parameter(Mandatory)][string]$Rule,
        [Parameter(Mandatory)][string]$Detail,
        [int]$Line = 1
    )

    return [pscustomobject]@{
        Severity = $Severity
        Rule     = $Rule
        Line     = $Line
        Detail   = $Detail
    }
}

function Test-CommitMarkdown {
    <# Adds a violation when a line carries Markdown the format forbids. #>
    param(
        [Parameter(Mandatory)][object]$Found,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][string]$Rule,
        [Parameter(Mandatory)][int]$Line
    )

    if ($Text -match $script:MarkdownPattern) {
        $Found.Add((New-CommitViolation -Severity error -Rule $Rule -Line $Line -Detail (
                    'Markdown renders literally in git log and GitHub commit views; write it bare.'
                )))
    }
}

function Get-DeclaredScope {
    <# Reads the host AGENTS.md '## Commit scopes' list. Empty when undeclared. #>
    param([string]$RepositoryRoot = '.')

    $policy = Join-Path $RepositoryRoot 'AGENTS.md'
    if (-not (Test-Path -LiteralPath $policy)) { return @() }

    $scopes = [System.Collections.Generic.List[string]]::new()
    $inSection = $false
    foreach ($line in [IO.File]::ReadAllLines($policy)) {
        if ($line -cmatch '^##\s') {
            $inSection = $line -cmatch '^##\s+Commit scopes\s*$'
            continue
        }
        if ($inSection -and $line -cmatch '^-\s+(?<scope>[a-z0-9][a-z0-9-]*)\s*$') {
            $scopes.Add($Matches['scope'])
        }
    }
    return $scopes.ToArray()
}

function Test-CommitSubject {
    <# Validates the subject line against the format. #>
    param(
        [Parameter(Mandatory)][object]$Found,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Subject,
        [AllowEmptyCollection()][string[]]$AllowedScope = @()
    )

    $match = [regex]::Match(
        $Subject, '^(?<type>[A-Za-z]+)(?:\((?<scope>[^)]*)\))?(?<break>!)?: (?<summary>.*)$')
    if (-not $match.Success) {
        $Found.Add((New-CommitViolation -Severity error -Rule 'subject.shape' -Detail (
                    "Subject must read 'type(scope): summary'; got '$Subject'."
                )))
    }
    else {
        $type = $match.Groups['type'].Value
        if ($script:CommitTypes -cnotcontains $type) {
            $Found.Add((New-CommitViolation -Severity error -Rule 'subject.type' -Detail (
                        "Type '$type' is not one of: $($script:CommitTypes -join ', ')."
                    )))
        }
        if ($match.Groups['scope'].Success) {
            $scope = $match.Groups['scope'].Value
            if ($scope -cnotmatch '^[a-z0-9][a-z0-9-]*$') {
                $Found.Add((New-CommitViolation -Severity error -Rule 'subject.scope' -Detail (
                            "Scope '$scope' must be lowercase."
                        )))
            }
            else {
                # An empty list means the host declares no scopes, so any shape passes.
                $allowed = @($AllowedScope | Where-Object { $_ })
                if ($allowed.Count -gt 0 -and $allowed -cnotcontains $scope) {
                    $Found.Add((New-CommitViolation -Severity error -Rule 'subject.scope' -Detail (
                                "Scope '$scope' is not declared under '## Commit scopes' in AGENTS.md: $($allowed -join ', ')."
                            )))
                }
            }
        }
        $summary = $match.Groups['summary'].Value
        if ([string]::IsNullOrWhiteSpace($summary)) {
            $Found.Add((New-CommitViolation -Severity error -Rule 'subject.summary' -Detail (
                        'The subject has no summary after the colon.'
                    )))
        }
        else {
            if ($summary -cmatch '^[A-Z]') {
                $Found.Add((New-CommitViolation -Severity error -Rule 'subject.case' -Detail (
                            'The summary starts uppercase; the format writes it lowercase.'
                        )))
            }
            if ($summary.EndsWith('.')) {
                $Found.Add((New-CommitViolation -Severity error -Rule 'subject.period' -Detail (
                            'The subject ends with a period; drop it.'
                        )))
            }
        }
    }

    if ($Subject.Length -gt $script:SubjectMaxLength) {
        $Found.Add((New-CommitViolation -Severity error -Rule 'subject.length' -Detail (
                    "The subject is $($Subject.Length) characters; the limit is $($script:SubjectMaxLength)."
                )))
    }
    Test-CommitMarkdown -Found $Found -Text $Subject -Rule 'subject.markdown' -Line 1
}

function Test-CommitEntry {
    <# Validates one body line as a list entry. #>
    param(
        [Parameter(Mandatory)][object]$Found,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][int]$Line
    )

    if ([string]::IsNullOrWhiteSpace($Text)) {
        $Found.Add((New-CommitViolation -Severity error -Rule 'body.blank' -Line $Line -Detail (
                    'The body holds no blank lines; the only blank line separates the footers.'
                )))
        return
    }
    if ($Text -cnotmatch '^- ') {
        $Found.Add((New-CommitViolation -Severity error -Rule 'body.entry' -Line $Line -Detail (
                    "Every body line is a '- ' entry; got '$Text'."
                )))
        return
    }
    if ($Text -cnotmatch '^- [A-Za-z]') {
        $Found.Add((New-CommitViolation -Severity error -Rule 'body.lead' -Line $Line -Detail (
                    'An entry starts with a letter; rephrase so no punctuation leads.'
                )))
    }
    if ($Text.EndsWith('.')) {
        $Found.Add((New-CommitViolation -Severity error -Rule 'body.period' -Line $Line -Detail (
                    'An entry takes no trailing period.'
                )))
    }
    if ($Text -cmatch '^- [A-Z]') {
        $Found.Add((New-CommitViolation -Severity warning -Rule 'body.case' -Line $Line -Detail (
                    'Entries read lowercase unless they lead with an identifier.'
                )))
    }
    if ($Text.Length -gt $script:EntryTargetLength) {
        $Found.Add((New-CommitViolation -Severity warning -Rule 'body.length' -Line $Line -Detail (
                    "The entry is $($Text.Length) characters; entries are never wrapped, so aim for $($script:EntryTargetLength)."
                )))
    }
    Test-CommitMarkdown -Found $Found -Text $Text -Rule 'body.markdown' -Line $Line
}

function Get-CommitMessageViolation {
    <# Validates a whole commit message and returns violations, errors first. #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Message,
        [AllowEmptyCollection()][string[]]$AllowedScope = @()
    )

    $found = [System.Collections.Generic.List[object]]::new()
    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ((($Message -replace "`r`n", "`n") -replace "`r", "`n") -split "`n")) {
        if ($line -cmatch '^#') { continue }
        $lines.Add($line)
    }
    while ($lines.Count -gt 0 -and [string]::IsNullOrWhiteSpace($lines[$lines.Count - 1])) {
        $lines.RemoveAt($lines.Count - 1)
    }
    if ($lines.Count -eq 0) {
        $found.Add((New-CommitViolation -Severity error -Rule 'message.empty' -Detail (
                    'The commit message is empty.'
                )))
        return $found
    }

    Test-CommitSubject -Found $found -Subject $lines[0] -AllowedScope $AllowedScope

    foreach ($index in 0..($lines.Count - 1)) {
        if ($lines[$index] -imatch $script:AttributionPattern) {
            $found.Add((New-CommitViolation -Severity error -Rule 'footer.attribution' -Line ($index + 1) -Detail (
                        'Attribution and co-author trailers are never added.'
                    )))
        }
    }

    if ($lines.Count -eq 1) { return $found }
    if (-not [string]::IsNullOrEmpty($lines[1])) {
        $found.Add((New-CommitViolation -Severity error -Rule 'body.separator' -Line 2 -Detail (
                    'A blank line separates the subject from the body.'
                )))
    }
    if ($lines.Count -lt 3) { return $found }

    $rest = $lines.GetRange(2, $lines.Count - 2)
    $bodyLines = $rest
    $blankIndex = -1
    for ($index = $rest.Count - 1; $index -ge 0; $index--) {
        if ([string]::IsNullOrWhiteSpace($rest[$index])) { $blankIndex = $index; break }
    }
    if ($blankIndex -ge 0) {
        $candidate = $rest.GetRange($blankIndex + 1, $rest.Count - $blankIndex - 1)
        $nonFooter = @($candidate | Where-Object { $_ -cnotmatch $script:FooterPattern })
        if ($candidate.Count -gt 0 -and $nonFooter.Count -eq 0) {
            $bodyLines = $rest.GetRange(0, $blankIndex)
        }
    }

    if ($bodyLines.Count -eq 0) { return $found }

    # A body with no entry markers at all is prose: report it once, not per line.
    $entryLines = @($bodyLines | Where-Object { $_ -cmatch '^- ' })
    if ($entryLines.Count -eq 0) {
        $found.Add((New-CommitViolation -Severity error -Rule 'body.prose' -Line 3 -Detail (
                    "The body is prose; rewrite it as 1 to $($script:EntryMaxCount) '- ' entries."
                )))
        return $found
    }

    foreach ($index in 0..($bodyLines.Count - 1)) {
        Test-CommitEntry -Found $found -Text $bodyLines[$index] -Line ($index + 3)
    }
    if ($bodyLines.Count -gt $script:EntryMaxCount) {
        $found.Add((New-CommitViolation -Severity error -Rule 'body.count' -Line 3 -Detail (
                    "The body holds $($bodyLines.Count) lines; the limit is $($script:EntryMaxCount) entries. Split the commit or merge points."
                )))
    }

    return $found
}

function Write-CommitViolation {
    <# Prints a violation report. Emits nothing when the message is clean. #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Violation,
        [string]$Label
    )

    if ($Violation.Count -eq 0) { return }

    if ($Label) { Write-Output $Label }
    foreach ($item in ($Violation | Sort-Object @{ Expression = { $_.Severity } }, Line)) {
        Write-Output ('  {0,-7} line {1,-3} {2,-20} {3}' -f
            $item.Severity, $item.Line, $item.Rule, $item.Detail)
    }
}

function Measure-CommitError {
    <# Counts the blocking violations in a report. #>
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Violation)

    return @($Violation | Where-Object { $_.Severity -eq 'error' }).Count
}

Export-ModuleMember -Function Get-CommitMessageViolation, Get-CommitType,
    Get-DeclaredScope, Measure-CommitError, Write-CommitViolation
