#Requires -Version 7
<# The package holds the policy, README, VERSION, LICENSE and the skills, never _repository, and refuses a mismatched tag. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$package = Join-Path $PSScriptRoot '..' 'package.ps1'
$failures = [Collections.Generic.List[string]]::new()
$root = Join-Path ([IO.Path]::GetTempPath()) ('pkg-test-' + [guid]::NewGuid().ToString('N'))
$out = Join-Path $root 'out'
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $root 'skills/actions/an-dr-x'), (Join-Path $root 'skills/_repository/an-dr-agents-repo-y'), (Join-Path $root 'docs/releases') | Out-Null
    foreach ($f in @('AGENTS.md', 'README.md', 'LICENSE', 'skills/README.md', 'skills/actions/an-dr-x/SKILL.md', 'skills/_repository/an-dr-agents-repo-y/SKILL.md')) {
        Set-Content -LiteralPath (Join-Path $root $f) -Value $f
    }
    Set-Content -LiteralPath (Join-Path $root 'VERSION') -Value '1.2.3'
    Set-Content -LiteralPath (Join-Path $root 'docs/releases/1.2.3.md') -Value 'notes'

    $zip = @(& pwsh -NoProfile -NonInteractive -File $package -Root $root -OutDirectory $out -Tag v1.2.3 2>&1)[-1]
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $zip)) { $failures.Add("Packaging failed: $zip") }
    else {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $entries = @([IO.Compression.ZipFile]::OpenRead($zip).Entries.FullName | ForEach-Object { $_.Replace([char]92, [char]47) })
        foreach ($expected in @('agents-1.2.3/AGENTS.md', 'agents-1.2.3/VERSION', 'agents-1.2.3/LICENSE', 'agents-1.2.3/README.md', 'agents-1.2.3/skills/actions/an-dr-x/SKILL.md')) {
            if ($expected -notin $entries) { $failures.Add("The package lacks $expected.") }
        }
        if (@($entries | Where-Object { $_ -match '_repository' }).Count -gt 0) { $failures.Add('The package carries skills/_repository.') }
        if ((Get-Content -Raw (Join-Path $out 'SHA256SUMS')) -notmatch '^[0-9a-f]{64}  agents-1\.2\.3\.zip$') { $failures.Add('SHA256SUMS is malformed.') }
    }
    $wrong = @(& pwsh -NoProfile -NonInteractive -File $package -Root $root -OutDirectory $out -Tag v9.9.9 2>&1) -join "`n"
    if ($LASTEXITCODE -eq 0 -or $wrong -notmatch 'does not match VERSION') { $failures.Add("A mismatched tag was packaged: $wrong") }
}
finally { Remove-Item -Recurse -Force -LiteralPath $root -ErrorAction SilentlyContinue }

if ($failures.Count -gt 0) { $failures | ForEach-Object { Write-Output "FAIL: $_" }; exit 1 }
Write-Output 'Package checks passed: contents, no _repository, checksum, tag check.'
