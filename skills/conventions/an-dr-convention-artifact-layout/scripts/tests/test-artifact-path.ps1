#Requires -Version 7
<# Checks path naming, kind and stamp validation, minute collisions, and latest copies. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Join-Path ([IO.Path]::GetTempPath()) "artifact-layout-$([guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $root | Out-Null
$new = Join-Path $PSScriptRoot '../new-artifact-path.ps1'
$publish = Join-Path $PSScriptRoot '../publish-latest.ps1'
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
try {
    $first = & $new -Kind code-review -Extension json -Stamp 2026-11-01_14-32 -RepositoryRoot $root
    Assert ($first -eq (Join-Path $root '.artifacts-temp/ai/code-review/code-review-2026-11-01_14-32.json')) "Unexpected path: $first"
    Assert (Test-Path (Join-Path $root '.artifacts-temp/.gitignore')) 'The .gitignore was not created.'
    Set-Content -LiteralPath $first -Value '{}'
    $html = & $new code-review html -Stamp 2026-11-01_14-32 -RepositoryRoot $root
    Set-Content -LiteralPath $html -Value '<html></html>'

    $auto = & $new code-review json -RepositoryRoot $root
    Set-Content -LiteralPath $auto -Value '{}'
    $again = & $new code-review json -RepositoryRoot $root
    Assert ($again -ne $auto -and $again -match '_\d{2}-\d{2}-\d+\.json$') "A used minute was not suffixed: $again"

    $copies = @(& $publish $first)
    Assert ($copies.Count -eq 2) "Expected two latest copies, got $($copies.Count)."
    Assert (Test-Path (Join-Path $root '.artifacts-temp/ai/code-review-latest.html')) 'The latest HTML is missing.'

    foreach ($bad in @(
            { & $new scratch html -RepositoryRoot $root },
            { & $new code-review HTML -RepositoryRoot $root },
            { & $new code-review html -Stamp 2026-11-01-A -RepositoryRoot $root },
            { & $publish (Join-Path $root 'elsewhere.html') })) {
        $failed = $false
        try { & $bad | Out-Null } catch { $failed = $true }
        Assert $failed "Expected a rejection: $bad"
    }
    Write-Output 'Artifact path checks passed.'
}
finally {
    Remove-Item -LiteralPath $root -Recurse -Force
}
