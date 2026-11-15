#Requires -Version 7
<# The register is enforced: owners write, named readers read named fields, nothing else passes. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$wip = Join-Path $PSScriptRoot '..' 'wip.ps1'
$failures = [Collections.Generic.List[string]]::new()
$root = Join-Path ([IO.Path]::GetTempPath()) ('wip-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null

function Invoke-Wip {
    param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
    $output = @(& pwsh -NoProfile -NonInteractive -File $wip @Arguments -Root $root 2>&1)
    return [pscustomobject]@{ Code = $LASTEXITCODE; Output = ($output -join "`n") }
}
function Assert-Refused([string]$Name, [string]$Pattern, [string[]]$Arguments) {
    $result = Invoke-Wip @Arguments
    if ($result.Code -eq 0) { $failures.Add("$Name was allowed.") }
    elseif ($result.Output -notmatch $Pattern) { $failures.Add("$Name refused for the wrong reason: $($result.Output)") }
}

try {
    $state = Join-Path $root 'state.json'
    Set-Content -LiteralPath $state -Value '{ "flow": "Vibe", "phase": "BUILD", "baseBranch": "dev" }'
    $owner = @('-Section', 'workflow', '-Owner', 'an-dr-dev-follow-workflow')

    if ((Invoke-Wip get -Section workflow -Reader an-dr-dev-follow-workflow).Output -ne 'null') { $failures.Add('An absent section is not null.') }
    $set = Invoke-Wip set @owner -JsonPath $state
    if ($set.Code -ne 0) { $failures.Add("The owner could not write: $($set.Output)") }
    if (-not (Test-Path (Join-Path $root 'tmp-agent-wip.json'))) { $failures.Add('The file is not tmp-agent-wip.json at the root.') }
    $read = Invoke-Wip get -Section workflow -Field baseBranch -Reader an-dr-dev-integrate
    if ($read.Output -ne '"dev"') { $failures.Add("A reader did not get its field: $($read.Output)") }
    $all = (Invoke-Wip get -Section workflow -Reader an-dr-dev-follow-workflow).Output | ConvertFrom-Json
    if ($all.phase -ne 'BUILD') { $failures.Add('The owner did not get the whole section.') }

    Assert-Refused 'an unknown section' 'Unknown section' @('get', '-Section', 'nope', '-Reader', 'x')
    Assert-Refused 'a foreign writer' 'belongs to' @('set', '-Section', 'workflow', '-Owner', 'an-dr-dev-integrate', '-JsonPath', $state)
    Assert-Refused 'an unlisted reader' 'may not read section' @('get', '-Section', 'workflow', '-Field', 'phase', '-Reader', 'an-dr-dev-review')
    Assert-Refused 'an unlisted field' "may not read 'workflow.phase'" @('get', '-Section', 'workflow', '-Field', 'phase', '-Reader', 'an-dr-dev-integrate')
    Assert-Refused 'a whole-section read by a reader' 'named fields' @('get', '-Section', 'workflow', '-Reader', 'an-dr-dev-integrate')
    Set-Content -LiteralPath $state -Value '{ "flow": "Vibe", "invented": 1 }'
    Assert-Refused 'an unknown field' 'has no field' (@('set') + $owner + @('-JsonPath', $state))

    $remove = Invoke-Wip remove @owner
    if ($remove.Code -ne 0 -or (Test-Path (Join-Path $root 'tmp-agent-wip.json'))) { $failures.Add('Removing the last section did not delete the file.') }
}
finally { Remove-Item -Recurse -Force -LiteralPath $root -ErrorAction SilentlyContinue }

if ($failures.Count -gt 0) { $failures | ForEach-Object { Write-Output "FAIL: $_" }; exit 1 }
Write-Output 'WIP data checks passed: owner writes, reader fields, refusals, removal.'
