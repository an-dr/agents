#Requires -Version 7
<# Validate behavior case data without invoking a model or materializing fixtures. #>
[CmdletBinding(DefaultParameterSetName = 'Path')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Path')][string]$Path,
    [Parameter(Mandatory, ParameterSetName = 'Json')][string]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if ($PSCmdlet.ParameterSetName -eq 'Path') { $Json = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).ProviderPath) }
$suite = ConvertFrom-Json -InputObject $Json -AsHashtable -ErrorAction Stop

function Assert-Object($Value, [string]$Where) {
    if ($Value -isnot [System.Collections.IDictionary]) { throw "$Where must be an object." }
}

function Assert-Text($Value, [string]$Where) {
    if ($Value -isnot [string] -or [string]::IsNullOrWhiteSpace($Value)) { throw "$Where must be nonempty text." }
}

function Assert-Fields($Value, [string[]]$Allowed, [string]$Where) {
    foreach ($key in $Value.psbase.Keys) {
        if ($key -cnotin $Allowed) { throw "$Where has unknown field '$key'." }
    }
}

function Assert-FileMap($Value, [string]$Where, [bool]$AllowEmpty = $false) {
    Assert-Object $Value $Where
    if ($Value.psbase.Count -eq 0 -and -not $AllowEmpty) { throw "$Where must contain files." }
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($filePath in $Value.psbase.Keys) {
        $segments = $filePath -split '/'
        if ($filePath -match '[\\:<>"|?*\x00-\x1f]' -or @($segments | Where-Object {
            $_ -in @('', '.', '..', '.git') -or $_ -match '[. ]$' -or $_ -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\.|$)'
        }).Count -gt 0) {
            throw "$Where has unsafe fixture path '$filePath'."
        }
        if (-not $seen.Add($filePath)) { throw "$Where has colliding fixture path '$filePath'." }
        if ($Value[$filePath] -isnot [string]) { throw "$Where file '$filePath' must contain text." }
    }
    # A file cannot also be an ancestor directory of another fixture.
    foreach ($filePath in $Value.psbase.Keys) {
        $segments = $filePath -split '/'
        for ($index = 1; $index -lt $segments.Count; $index++) {
            $parent = $segments[0..($index - 1)] -join '/'
            if ($seen.Contains($parent)) { throw "$Where has a file/directory collision at '$parent'." }
        }
    }
}

Assert-Object $suite 'suite'
Assert-Fields $suite @('schema_version', 'cases') 'suite'
if (-not $suite.Contains('schema_version')) { throw 'suite.schema_version must be integer 1.' }
if (($suite.schema_version -isnot [long] -and $suite.schema_version -isnot [int]) -or $suite.schema_version -ne 1) {
    throw 'suite.schema_version must be integer 1.'
}
if (-not $suite.Contains('cases') -or $suite.cases -isnot [array] -or $suite.cases.Count -eq 0) { throw 'suite.cases must be a nonempty array.' }
$ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($case in $suite.cases) {
    Assert-Object $case 'case'
    Assert-Fields $case @('id', 'prompt', 'context', 'files', 'before', 'after', 'unchanged', 'follow_up', 'expectations') 'case'
    foreach ($field in @('id', 'prompt')) {
        if (-not $case.Contains($field)) { throw "case is missing '$field'." }
        Assert-Text $case[$field] "case.$field"
    }
    $label = $case.id
    if (-not $ids.Add($label)) { throw "Duplicate case ID '$label'." }
    if ($case.Contains('context')) { Assert-Text $case.context "$label.context" }
    if (-not $case.Contains('context') -and -not $case.Contains('files') -and -not $case.Contains('before')) { throw "$label needs input evidence." }
    foreach ($field in @('expectations', 'follow_up')) {
        if ($field -eq 'follow_up' -and -not $case.Contains($field)) { continue }
        if (-not $case.Contains($field) -or $case[$field] -isnot [array] -or $case[$field].Count -eq 0) { throw "$label.$field must be a nonempty array." }
        foreach ($item in $case[$field]) { Assert-Text $item "$label.$field item" }
    }
    $hasDiff = $case.Contains('before') -or $case.Contains('after')
    if ($hasDiff -and (-not $case.Contains('before') -or -not $case.Contains('after'))) { throw "$label needs both before and after." }
    if ($hasDiff -and $case.Contains('files')) { throw "$label cannot mix files and diff maps." }
    if ($case.Contains('unchanged') -and -not $hasDiff) { throw "$label.unchanged requires diff maps." }
    foreach ($field in @('files', 'before', 'after', 'unchanged')) {
        if ($case.Contains($field)) { Assert-FileMap $case[$field] "$label.$field" ($field -in @('before', 'after')) }
    }
    if ($hasDiff -and $case.before.psbase.Count -eq 0 -and $case.after.psbase.Count -eq 0) { throw "$label diff maps must contain at least one file." }
    if ($case.Contains('unchanged')) {
        foreach ($field in @('before', 'after')) {
            $combined = [ordered]@{}
            foreach ($key in $case[$field].psbase.Keys) { $combined[$key] = $case[$field][$key] }
            foreach ($key in $case.unchanged.psbase.Keys) {
                if ($combined.Contains($key)) { throw "$label.unchanged overlaps '$key'." }
                $combined[$key] = $case.unchanged[$key]
            }
            Assert-FileMap $combined "$label combined $field"
        }
    }
}
Write-Output "Behavior case structure passed: $($suite.cases.Count) case(s). No agent evaluations ran."
