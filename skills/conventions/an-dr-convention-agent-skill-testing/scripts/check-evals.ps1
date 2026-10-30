#Requires -Version 7
<# Validate evaluation data and archives without extracting fixtures or invoking models. #>
[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Path')][string]$Path,
    [Parameter(Mandatory, ParameterSetName = 'Json')][string]$Json,
    [Parameter(ParameterSetName = 'Json')][string]$SuiteRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSCmdlet.ParameterSetName -eq 'Path') {
    $resolved = (Resolve-Path -LiteralPath $Path).ProviderPath
    $SuiteRoot = Split-Path -Parent $resolved
    $Json = [IO.File]::ReadAllText($resolved)
}
$suite = ConvertFrom-Json -InputObject $Json -AsHashtable -ErrorAction Stop
function Assert-Object($Value, [string]$Where) {
    if ($Value -isnot [Collections.IDictionary]) { throw "$Where must be an object." }
}
function Assert-Text($Value, [string]$Where) {
    if ($Value -isnot [string] -or [string]::IsNullOrWhiteSpace($Value)) { throw "$Where must be nonempty text." }
}
function Assert-Fields($Value, [string[]]$Allowed, [string[]]$Required, [string]$Where) {
    Assert-Object $Value $Where
    foreach ($key in $Value.psbase.Keys) {
        if ($key -cnotin $Allowed) { throw "$Where has unknown field '$key'." }
    }
    foreach ($key in $Required) { if (-not $Value.Contains($key)) { throw "$Where is missing '$key'." } }
}
function Assert-Array($Value, [string]$Where, [bool]$AllowEmpty = $false) {
    if ($Value -isnot [array] -or (-not $AllowEmpty -and $Value.Count -eq 0)) { throw "$Where must be a nonempty array (unless explicitly allowed empty)." }
}
function Assert-Texts($Value, [string]$Where, [bool]$AllowEmpty = $false) {
    Assert-Array $Value $Where $AllowEmpty
    foreach ($item in $Value) { Assert-Text $item "$Where item" }
}
function Assert-Integer($Value, [string]$Where, [bool]$Positive = $false) {
    if (($Value -isnot [int] -and $Value -isnot [long]) -or ($Positive -and $Value -lt 1)) { throw "$Where must be an integer$(if ($Positive) { ' greater than zero' })." }
}
function Assert-SafePath([string]$Value) {
    Assert-Text $Value 'path'
    $segments = $Value -split '/'
    if ($Value -match '[\\:<>"|?*\x00-\x1f]' -or @($segments | Where-Object {
        $_ -in @('', '.', '..', '.git') -or $_ -match '[. ]$' -or $_ -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)'
    }).Count -gt 0) { throw "unsafe path '$Value'." }
}
function Resolve-SuiteFile([string]$Relative) {
    Assert-SafePath $Relative
    if (-not $SuiteRoot) { throw 'SuiteRoot is required to validate fixture or grader files.' }
    $root = [IO.Path]::GetFullPath($SuiteRoot)
    $ancestor = [IO.DirectoryInfo]::new($root)
    while ($null -ne $ancestor) {
        if ($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point suite ancestor: $($ancestor.FullName)" }
        $ancestor = $ancestor.Parent
    }
    $current = $root
    if ((Get-Item -LiteralPath $root).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point suite root: $root" }
    foreach ($part in ($Relative -split '/')) {
        $current = Join-Path $current $part
        if (-not (Test-Path -LiteralPath $current)) { throw "Missing suite file '$Relative'." }
        if ((Get-Item -LiteralPath $current).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw "Reparse point in '$Relative'." }
    }
    if (-not (Test-Path -LiteralPath $current -PathType Leaf)) { throw "Not a file: '$Relative'." }
    return $current
}
$environmentFields = @('host','model','os','tools','network','permissions','discovery','instructions','workspace')
function Assert-Environment($Value, [bool]$Partial = $false) {
    $required = if ($Partial) { @() } else { $environmentFields }
    Assert-Fields $Value $environmentFields $required 'environment'
    foreach ($key in @('host','model')) { if ($Value.Contains($key)) { Assert-Text $Value[$key] "environment.$key" } }
    foreach ($key in @('os','tools','instructions')) { if ($Value.Contains($key)) { Assert-Texts $Value[$key] "environment.$key" ($key -eq 'tools') } }
    if ($Value.Contains('os')) { foreach ($os in $Value.os) { if ($os -cnotin @('windows','linux','macos')) { throw "Unsupported environment.os '$os'." } } }
    foreach ($key in @('network','permissions','discovery','workspace')) {
        if (-not $Value.Contains($key)) { continue }
        $allowed = switch ($key) {
            network { @('disabled','fixture-only') }
            permissions { @('workspace-only') }
            discovery { @('host-native') }
            workspace { @('fresh-git') }
        }
        if ($Value[$key] -cnotin $allowed) { throw "Invalid environment.$key." }
    }
}
function Assert-Regex($Value) {
    Assert-Text $Value 'pattern'
    try { $null = [regex]::new($Value, [Text.RegularExpressions.RegexOptions]::None, [TimeSpan]::FromSeconds(1)) }
    catch { throw "Invalid regex '$Value'." }
}
function Assert-Archive([string]$Relative, $Seen) {
    if ($Relative -cnotmatch '^fixtures/.+\.zip$') { throw 'fixtures must reference ZIP files under fixtures/.' }
    $file = Resolve-SuiteFile $Relative
    $archive = [IO.Compression.ZipFile]::OpenRead($file)
    try {
        if ($archive.Entries.Count -eq 0 -or $archive.Entries.Count -gt 10000) { throw 'Archive must have 1 to 10000 entries.' }
        $declaredSize = 0L
        $actualSize = 0L
        foreach ($entry in $archive.Entries) {
            $entryPath = $entry.FullName
            Assert-SafePath $entryPath
            if ($entryPath -cnotmatch '^(baseline|working)/.+') { throw "Archive entry outside baseline/ or working/: $entryPath" }
            $mode = ($entry.ExternalAttributes -shr 16) -band 0xF000
            if ($mode -ne 0 -and $mode -ne 0x8000) { throw "Archive entry must be an ordinary file: $entryPath" }
            if ($entry.ExternalAttributes -band 0x400) { throw "Archive reparse point: $entryPath" }
            if (-not $Seen.Add($entryPath)) { throw "Archive path collision: $entryPath" }
            $declaredSize += $entry.Length
            if ($declaredSize -gt 100MB) { throw 'Archive exceeds 100 MiB uncompressed.' }
            # Bound decompression too: archive metadata alone is not a trustworthy size limit.
            $stream = $entry.Open()
            $decoder = [Text.UTF8Encoding]::new($false, $true).GetDecoder()
            $buffer = [byte[]]::new(8192)
            $characters = [char[]]::new(8193)
            $entrySize = 0L
            try {
                while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $actualSize += $read
                    $entrySize += $read
                    if ($actualSize -gt 100MB) { throw 'Archive exceeds 100 MiB uncompressed.' }
                    $null = $decoder.GetChars($buffer, 0, $read, $characters, 0, $false)
                }
                $null = $decoder.GetChars($buffer, 0, 0, $characters, 0, $true)
                if ($entrySize -ne $entry.Length) { throw "Archive size mismatch: $entryPath" }
            } finally { $stream.Dispose() }
        }
    } finally { $archive.Dispose() }
}
Assert-Fields $suite @('schema_version','skill_name','environment','evals') @('schema_version','skill_name','environment','evals') 'suite'
Assert-Integer $suite.schema_version 'schema_version'
if ($suite.schema_version -ne 1) { throw 'schema_version must be integer 1.' }
Assert-Text $suite.skill_name 'skill_name'
if ($suite.skill_name -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$') { throw 'Invalid skill_name.' }
Assert-Environment $suite.environment
Assert-Array $suite.evals 'evals'
$ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$buckets = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($case in $suite.evals) {
    $required = @('id','bucket','prompt','expected_skill','expected_behavior','assertions','runs')
    Assert-Fields $case ($required + @('context','fixtures','follow_up','environment')) $required 'case'
    foreach ($key in @('id','prompt')) { Assert-Text $case[$key] "case.$key" }
    if (-not $ids.Add($case.id)) { throw "Duplicate case ID '$($case.id)'." }
    if ($case.bucket -cnotin @('explicit','implicit','contextual','negative')) { throw 'Invalid bucket.' }
    $null = $buckets.Add($case.bucket)
    if ($case.bucket -ceq 'negative') {
        if ($null -ne $case.expected_skill) { throw 'Negative expected_skill must be null.' }
    } elseif ($case.expected_skill -cne $suite.skill_name) { throw 'Positive expected_skill must match skill_name.' }
    if ($case.bucket -ceq 'explicit' -and -not $case.prompt.Contains($suite.skill_name)) { throw 'Explicit prompt must name skill_name.' }
    if ($case.bucket -cin @('implicit','contextual') -and $case.prompt.Contains($suite.skill_name)) { throw 'Discovery prompt must not name skill_name.' }
    Assert-Integer $case.runs 'runs' $true
    Assert-Texts $case.expected_behavior 'expected_behavior'
    if ($case.Contains('context')) { Assert-Text $case.context 'context' }
    if ($case.Contains('follow_up')) { Assert-Texts $case.follow_up 'follow_up' }
    if ($case.Contains('environment')) { Assert-Environment $case.environment $true }
    if ($case.Contains('fixtures')) {
        Assert-Texts $case.fixtures 'fixtures'
        $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach ($fixture in $case.fixtures) { Assert-Archive $fixture $seen }
        foreach ($filePath in $seen) {
            $parts = $filePath -split '/'
            for ($i = 1; $i -lt $parts.Count; $i++) {
                if ($seen.Contains(($parts[0..($i-1)] -join '/'))) { throw "Archive file/directory collision: $filePath" }
            }
        }
    }
    Assert-Array $case.assertions 'assertions'
    foreach ($assertion in $case.assertions) {
        Assert-Object $assertion 'assertion'
        if (-not $assertion.Contains('type')) { throw 'assertion is missing type.' }
        $fields = switch -CaseSensitive ($assertion.type) {
            invocation_check { @('expected') }
            transcript_check { @('pattern') }
            file_check { @('path','contains') }
            exit_code { @('command_pattern','expected') }
            diff_scope { @('allowed_paths') }
            deterministic { @('script') }
            llm_judge { @('rubric') }
            default { throw "Unknown assertion type '$($assertion.type)'." }
        }
        $requiredFields = @($fields | Where-Object { $_ -ne 'contains' })
        Assert-Fields $assertion (@('type') + $fields) (@('type') + $requiredFields) 'assertion'
        switch -CaseSensitive ($assertion.type) {
            invocation_check { if ($assertion.expected -isnot [bool]) { throw 'invocation_check.expected must be boolean.' } }
            transcript_check { Assert-Regex $assertion.pattern }
            file_check {
                Assert-SafePath $assertion.path
                if ($assertion.Contains('contains')) { Assert-Text $assertion.contains 'contains' }
            }
            exit_code { Assert-Regex $assertion.command_pattern; Assert-Integer $assertion.expected 'exit_code.expected' }
            diff_scope { Assert-Texts $assertion.allowed_paths 'allowed_paths' $true; foreach ($p in $assertion.allowed_paths) { Assert-SafePath $p } }
            deterministic {
                if ($assertion.script -cnotmatch '^graders/.+\.ps1$') { throw 'deterministic script must be under graders/ and end in .ps1.' }
                $null = Resolve-SuiteFile $assertion.script
            }
            llm_judge { Assert-Text $assertion.rubric 'rubric' }
        }
    }
}
foreach ($bucket in @('explicit','implicit','contextual','negative')) { if (-not $buckets.Contains($bucket)) { throw "Missing bucket '$bucket'." } }
Write-Output "Evaluation structure passed: $($suite.evals.Count) case(s). No agent evaluations ran."
