#Requires -Version 7
<# Execute the public validator against valid suites and malformed contracts/archives. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$checker = Join-Path $PSScriptRoot '../check-evals.ps1'
$caseCount = 0
function New-Suite {
    $name = 'example-skill'
    $cases = foreach ($bucket in @('explicit','implicit','contextual','negative')) {
        @{ id = $bucket; bucket = $bucket; prompt = $(if ($bucket -eq 'explicit') { "Use $name to summarize this log." } else { 'Summarize this log.' }); expected_skill = $(if ($bucket -eq 'negative') { $null } else { $name }); expected_behavior = @('Preserves facts.'); assertions = @(@{ type = 'diff_scope'; allowed_paths = @() }); runs = 5 }
    }
    return @{ schema_version = 1; skill_name = $name; environment = @{ host = 'current'; model = 'current'; os = @('windows','linux','macos'); tools = @('git'); network = 'disabled'; permissions = 'workspace-only'; discovery = 'host-native'; instructions = @('target-and-dependencies'); workspace = 'fresh-git' }; evals = @($cases) }
}
function Assert-Check([string]$Name, $Suite, [int]$Exit, [string]$Message, [string]$Root = '') {
    $json = ConvertTo-Json -InputObject $Suite -Depth 30 -Compress
    $arguments = @('-NoProfile','-NonInteractive','-File',$checker,'-Json',$json)
    if ($Root) { $arguments += @('-SuiteRoot',$Root) }
    $output = (& pwsh @arguments 2>&1) -join "`n"
    if ($LASTEXITCODE -ne $Exit -or -not $output.Contains($Message)) { throw "$Name`: expected exit $Exit and '$Message'; got $LASTEXITCODE.`n$output" }
    $script:caseCount++
}
$suite = New-Suite
Assert-Check 'valid minimal suite' $suite 0 '4 case(s)'
$suite.evals[0].follow_up = @('Now summarize the second log.')
$suite.evals[0].environment = @{ tools = @('git','pwsh') }
$suite.evals[0].assertions = @(@{ type='invocation_check';expected=$true }, @{ type='transcript_check';pattern='git status' }, @{ type='file_check';path='out/report.md';contains='Summary' }, @{ type='exit_code';command_pattern='validate';expected=0 }, @{ type='llm_judge';rubric='Preserves facts.' })
Assert-Check 'all inline assertion types and overrides' $suite 0 '4 case(s)'
foreach ($field in @('schema_version','skill_name','environment','evals')) {
    $suite = New-Suite; $suite.Remove($field)
    Assert-Check "missing $field" $suite 1 $field
}
foreach ($field in @('host','model','os','tools','network','permissions','discovery','instructions','workspace')) {
    $suite = New-Suite; $suite.environment.Remove($field)
    Assert-Check "missing environment $field" $suite 1 $field
}
foreach ($field in @('id','bucket','prompt','expected_skill','expected_behavior','assertions','runs')) {
    $suite = New-Suite; $suite.evals[0].Remove($field)
    Assert-Check "missing case $field" $suite 1 $field
}
$suite=New-Suite;$suite.schema_version=2;Assert-Check 'version' $suite 1 'schema_version'
$suite=New-Suite;$suite.evals[1].id='EXPLICIT';Assert-Check 'duplicate ID' $suite 1 'Duplicate case ID'
$suite=New-Suite;$suite.evals=$suite.evals[0..2];Assert-Check 'missing bucket' $suite 1 'Missing bucket'
$suite=New-Suite;$suite.evals[3].expected_skill='example-skill';Assert-Check 'negative target' $suite 1 'must be null'
$suite=New-Suite;$suite.evals[0].expected_skill=$null;Assert-Check 'positive target' $suite 1 'must match'
$suite=New-Suite;$suite.evals[1].prompt='Use example-skill';Assert-Check 'discovery leakage' $suite 1 'must not name'
$suite=New-Suite;$suite.evals[0].prompt='Summarize.';Assert-Check 'explicit missing name' $suite 1 'must name'
$suite=New-Suite;$suite.evals[0].runs=0;Assert-Check 'zero trials' $suite 1 'greater than zero'
$suite=New-Suite;$suite.evals[0].runs='5';Assert-Check 'string trials' $suite 1 'integer'
$suite=New-Suite;$suite.environment.network='live';Assert-Check 'live services' $suite 1 'environment.network'
$suite=New-Suite;$suite.environment.os=@('unknown');Assert-Check 'OS contract' $suite 1 'environment.os'
$suite=New-Suite;$suite.extra=1;Assert-Check 'unknown suite field' $suite 1 'unknown field'
$suite=New-Suite;$suite.evals[0].files=@{};Assert-Check 'legacy inline fixture' $suite 1 'unknown field'
$suite=New-Suite;$suite.evals[0].assertions=@(@{type='unknown'});Assert-Check 'unknown assertion' $suite 1 'Unknown assertion'
$suite=New-Suite;$suite.evals[0].assertions=@(@{type='invocation_check';expected='true'});Assert-Check 'boolean assertion' $suite 1 'boolean'
$suite=New-Suite;$suite.evals[0].assertions=@(@{type='transcript_check';pattern='['});Assert-Check 'bad regex' $suite 1 'Invalid regex'
foreach ($path in @('../escape','/absolute','C:/drive','a\b','a//b','.git/config','NUL.txt','a./b')) {
    $suite=New-Suite;$suite.evals[0].assertions=@(@{type='file_check';path=$path});Assert-Check "unsafe $path" $suite 1 'unsafe path'
}
# Fixtures are created only in a fresh temporary test directory, never in the user's repo.
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('skill-eval-validator-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path (Join-Path $scratch 'fixtures')
function Write-Zip([string[]]$Names, [bool]$Link = $false) {
    $path = Join-Path $scratch 'fixtures/input.zip'
    $stream = [IO.File]::Create($path)
    $zip = [IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($name in $Names) {
            $entry=$zip.CreateEntry($name)
            if ($Link) { $entry.ExternalAttributes = (0xA000 -shl 16) }
            $writer=[IO.StreamWriter]::new($entry.Open());try { $writer.Write('input') } finally { $writer.Dispose() }
        }
    } finally { $zip.Dispose();$stream.Dispose() }
}
try {
    $suite=New-Suite;$suite.evals[0].fixtures=@('fixtures/input.zip')
    Assert-Check 'missing ZIP' $suite 1 'Missing suite file' $scratch
    Write-Zip @('baseline/src/a.txt','working/src/a.txt');Assert-Check 'valid ZIP' $suite 0 '4 case(s)' $scratch
    Write-Zip @('working/new.txt');Assert-Check 'addition-only ZIP' $suite 0 '4 case(s)' $scratch
    Write-Zip @('baseline/deleted.txt');Assert-Check 'deletion-only ZIP' $suite 0 '4 case(s)' $scratch
    foreach ($name in @('baseline/../escape','/absolute','baseline/.git/config','baseline/NUL.txt','baseline/a\b')) {
        Write-Zip @($name);Assert-Check "unsafe archive $name" $suite 1 'unsafe path' $scratch
    }
    Write-Zip @('other/a');Assert-Check 'archive root' $suite 1 'outside baseline' $scratch
    Write-Zip @('baseline/a','baseline/A');Assert-Check 'archive case collision' $suite 1 'path collision' $scratch
    Write-Zip @('baseline/a','baseline/a/b');Assert-Check 'archive ancestor collision' $suite 1 'file/directory collision' $scratch
    Write-Zip @('baseline/link') $true;Assert-Check 'archive symlink' $suite 1 'ordinary file' $scratch
    $suite.evals[0].fixtures=@('fixtures/../input.zip');Assert-Check 'fixture traversal' $suite 1 'unsafe path' $scratch
    $suite=New-Suite;$suite.evals[0].assertions=@(@{type='deterministic';script='graders/missing.ps1'});Assert-Check 'missing grader' $suite 1 'Missing suite file' $scratch
} finally {
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    $resolvedScratch = [IO.Path]::GetFullPath($scratch)
    if (-not $resolvedScratch.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or -not (Split-Path -Leaf $resolvedScratch).StartsWith('skill-eval-validator-')) { throw 'Unsafe scratch cleanup.' }
    Remove-Item -LiteralPath $resolvedScratch -Recurse -Force
}
Write-Output "check-evals regression tests passed ($caseCount cases). No agent evaluations ran."
