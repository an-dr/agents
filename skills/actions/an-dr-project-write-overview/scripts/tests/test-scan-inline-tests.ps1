#Requires -Version 7
<# Checks that scan-project.ps1 counts Rust files with inline test modules apart from test files. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Join-Path ([IO.Path]::GetTempPath()) "scan-inline-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path (Join-Path $root 'src') -Force | Out-Null
$script = Join-Path $PSScriptRoot '../scan-project.ps1'
$json = Join-Path $root 'scan.json'
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
try {
    Set-Content -LiteralPath (Join-Path $root 'src/lib.rs') -Value "pub fn one() -> u8 { 1 }`n`n#[cfg(test)]`nmod tests {`n    #[test]`n    fn works() { assert_eq!(super::one(), 1); }`n}"
    Set-Content -LiteralPath (Join-Path $root 'src/plain.rs') -Value 'pub fn two() -> u8 { 2 }'
    Set-Content -LiteralPath (Join-Path $root 'src/notes.py') -Value '# mentions #[test] but is not Rust'
    & pwsh -NoProfile -NonInteractive -File $script -Path $root -Json $json *> $null
    Assert ($LASTEXITCODE -eq 0) 'The scan failed.'
    $tests = (Get-Content -LiteralPath $json -Raw | ConvertFrom-Json).tests
    Assert ($tests.files -eq 0) "Expected 0 test files, got $($tests.files)."
    Assert ($tests.inline -eq 1) "Expected 1 file with inline tests, got $($tests.inline)."
    Write-Output 'Inline test detection checks passed.'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force
}
