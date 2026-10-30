#Requires -Version 7
<# Exercise suite validation with in-memory data; no models or fixture writes. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$checker = Join-Path $PSScriptRoot '../scripts/check-test-cases.ps1'
$caseCount = 0

function New-Suite {
    return @{ schema_version = 1; cases = @(@{ id = 'CASE-001'; prompt = 'Analyze the supplied input.'; context = 'A concrete input.'; expectations = @('Leaves input unchanged.') }) }
}

function Assert-Check([string]$Name, $Suite, [int]$Exit, [string]$Message) {
    $json = ConvertTo-Json -InputObject $Suite -Depth 20 -Compress
    $output = (& pwsh -NoProfile -File $checker -Json $json 2>&1) -join "`n"
    if ($LASTEXITCODE -ne $Exit -or -not $output.Contains($Message)) { throw "$Name`: expected exit $Exit and '$Message'; got $LASTEXITCODE.`n$output" }
    $script:caseCount++
}

$suite = New-Suite
Assert-Check 'context only' $suite 0 '1 case(s)'
$suite.cases[0].follow_up = @('Revise with new evidence.')
Assert-Check 'conversation' $suite 0 '1 case(s)'
$suite = New-Suite
$suite.cases[0].Remove('context')
$suite.cases[0].files = @{ 'src/input.txt' = '' }
Assert-Check 'empty text file supplies evidence' $suite 0 '1 case(s)'
$suite = New-Suite
$suite.cases[0].before = @{ 'old.txt' = 'old' }
$suite.cases[0].after = @{ 'new.txt' = 'new' }
$suite.cases[0].unchanged = @{ 'kept.txt' = 'kept' }
Assert-Check 'diff permits added and deleted paths' $suite 0 '1 case(s)'
$suite.cases[0].before = @{}
Assert-Check 'addition only' $suite 0 '1 case(s)'
$suite.cases[0].before = @{ 'old.txt' = 'old' }
$suite.cases[0].after = @{}
Assert-Check 'deletion only' $suite 0 '1 case(s)'

foreach ($version in @('1', 2, $null)) {
    $suite = New-Suite
    $suite.schema_version = $version
    Assert-Check 'unsupported version' $suite 1 'schema_version must be integer 1'
}
$suite = New-Suite
$suite.Remove('schema_version')
Assert-Check 'missing version' $suite 1 'schema_version must be integer 1'
$suite = New-Suite
$suite.cases = @()
Assert-Check 'empty suite' $suite 1 'cases must be a nonempty array'
$suite = New-Suite
$suite.cases += @{ id = 'case-001'; prompt = 'Another request'; context = 'Evidence'; expectations = @('Expected outcome') }
Assert-Check 'duplicate ID' $suite 1 'Duplicate case ID'
foreach ($field in @('id', 'prompt', 'expectations')) {
    $suite = New-Suite
    $suite.cases[0].Remove($field)
    Assert-Check "missing $field" $suite 1 $field
}
$suite = New-Suite
$suite.cases[0].expectations = 'Not an array'
Assert-Check 'scalar rubric' $suite 1 'expectations must be a nonempty array'
$suite = New-Suite
$suite.cases[0].expectations = @(' ')
Assert-Check 'blank criterion' $suite 1 'must be nonempty text'
$suite = New-Suite
$suite.cases[0].follow_up = @()
Assert-Check 'empty conversation' $suite 1 'follow_up must be a nonempty array'
$suite = New-Suite
$suite.cases[0].Remove('context')
Assert-Check 'no evidence' $suite 1 'needs input evidence'
$suite = New-Suite
$suite.cases[0].contex = 'A typo'
Assert-Check 'unknown field' $suite 1 "unknown field 'contex'"
$suite = New-Suite
$suite.cases[0].before = @{ 'a' = 'a' }
Assert-Check 'partial diff' $suite 1 'needs both before and after'
$suite.cases[0].after = @{ 'a' = 'b' }
$suite.cases[0].files = @{ 'b' = 'c' }
Assert-Check 'mixed fixture modes' $suite 1 'cannot mix files and diff maps'
$suite = New-Suite
$suite.cases[0].unchanged = @{ 'a' = 'a' }
Assert-Check 'unchanged without diff' $suite 1 'unchanged requires diff maps'

foreach ($path in @('../escape', '/absolute', 'C:/drive', 'a\b', 'a//b', './a', '.GiT/config', 'a./b', 'a /b', 'a:stream', 'a*', 'NUL.txt')) {
    $suite = New-Suite
    $suite.cases[0].files = @{ $path = 'data' }
    Assert-Check "unsafe path $path" $suite 1 'unsafe fixture path'
}
$suite = New-Suite
$suite.cases[0].files = @{ 'a' = 42 }
Assert-Check 'non-text content' $suite 1 'must contain text'
$suite = New-Suite
$suite.cases[0].files = @{ 'a' = 'file'; 'a/b' = 'nested' }
Assert-Check 'file directory collision' $suite 1 'file/directory collision'
$suite = New-Suite
$suite.cases[0].before = @{ 'A' = 'old' }
$suite.cases[0].after = @{ 'A' = 'new' }
$suite.cases[0].unchanged = @{ 'a' = 'kept' }
Assert-Check 'unchanged overlaps diff' $suite 1 'overlaps'
$suite.cases[0].unchanged = @{ 'a/b' = 'kept' }
Assert-Check 'cross-map ancestor collision' $suite 1 'file/directory collision'
$suite = New-Suite
# Preserve both keys while serializing this invalid fixture.
$suite.cases[0].files = [Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
$suite.cases[0].files.Add('a.txt', 'one')
$suite.cases[0].files.Add('A.TXT', 'two')
Assert-Check 'case-insensitive path collision' $suite 1 'colliding fixture path'
$suite = New-Suite
$suite.cases[0].files = @{ 'Keys' = 'data'; 'Count' = 'data'; 'Values' = 'data' }
Assert-Check 'dictionary member names are valid paths' $suite 0 '1 case(s)'
$suite = New-Suite
$suite.cases[0].before = @{ 'Count' = 'old' }
$suite.cases[0].after = @{ 'Count' = 'new' }
Assert-Check 'diff map member names' $suite 0 '1 case(s)'
$suite.cases[0].before = @{}
$suite.cases[0].after = @{}
Assert-Check 'empty diff pair' $suite 1 'diff maps must contain at least one file'
$suite = New-Suite
$suite.extra = 'unknown'
Assert-Check 'unknown suite field' $suite 1 'unknown field'
$suite = New-Suite
$suite.cases[0].files = @{}
Assert-Check 'empty ordinary file map' $suite 1 'must contain files'
$suite.cases[0].files = @('not', 'a', 'map')
Assert-Check 'array as file map' $suite 1 'must be an object'
$suite = New-Suite
$suite.cases[0].context = ''
Assert-Check 'empty context' $suite 1 'must be nonempty text'
$suite = New-Suite
$suite.cases[0].prompt = ' '
Assert-Check 'empty prompt' $suite 1 'must be nonempty text'
Assert-Check 'array suite root' @() 1 'must be an object'
$suite = New-Suite
$suite.cases = @('not an object')
Assert-Check 'non-object case' $suite 1 'must be an object'
Write-Output "check-test-cases tests passed ($caseCount cases)."
