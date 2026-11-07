#Requires -Version 7
<# Checks that check-layout.ps1 passes a conforming repository and reports each rule's violation. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script = Join-Path $PSScriptRoot '../check-layout.ps1'
function Assert([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }

function New-Repository([string[]]$Files) {
    $root = Join-Path ([IO.Path]::GetTempPath()) "check-layout-$([guid]::NewGuid().ToString('N'))"
    New-Item -ItemType Directory -Path $root | Out-Null
    git -C $root init --quiet
    foreach ($file in $Files) {
        $full = Join-Path $root $file
        New-Item -ItemType Directory -Path (Split-Path $full) -Force | Out-Null
        Set-Content -LiteralPath $full -Value 'x'
    }
    git -C $root add --all
    return $root
}

function Invoke-Check([string]$Root) {
    $output = @(& pwsh -NoProfile -NonInteractive -File $script -Path $Root 2>&1)
    return [pscustomobject]@{ Code = $LASTEXITCODE; Text = ($output -join "`n") }
}

$roots = [Collections.Generic.List[string]]::new()
try {
    $clean = New-Repository @('README.md', 'LICENSE', 'docs/index.md', 'apps/tool/Cargo.toml', 'apps/tool/src/main.rs',
        'apps/suite/host/main.rs', 'apps/suite/web/index.ts', 'tests/unit/a.rs')
    $roots.Add($clean)
    $result = Invoke-Check $clean
    Assert ($result.Code -eq 0) "Conforming repository failed: $($result.Text)"

    $bad = New-Repository @('README.md', 'doc/index.md', 'example/a.c', '.artifacts/code-review/r.json',
        'code-review/r.html', 'pkg/__pycache__/m.pyc', 'apps/cross-wall/host/Cargo.toml', 'apps/cross-wall/host/src/main.rs')
    $roots.Add($bad)
    $result = Invoke-Check $bad
    Assert ($result.Code -eq 1) "Expected exit 1, got $($result.Code): $($result.Text)"
    foreach ($expected in '| warning | root-file | `LICENSE`', '`doc/`', '`example/`', '`.artifacts/`', '`code-review/`',
        '`pkg/__pycache__/`', '| error | empty-nesting | `apps/cross-wall/host/`') {
        Assert ($result.Text.Contains($expected)) "Missing '$expected' in: $($result.Text)"
    }
    Assert (-not $result.Text.Contains('`.artifacts/code-review/`')) "Reported a nested generated folder twice: $($result.Text)"

    $warningOnly = New-Repository @('README.md', 'src/main.c')
    $roots.Add($warningOnly)
    $result = Invoke-Check $warningOnly
    Assert ($result.Code -eq 0) "A missing LICENSE alone must not fail: $($result.Text)"
    Assert ($result.Text.Contains('0 error(s), 1 warning(s).')) "Expected one warning: $($result.Text)"

    Write-Output 'Layout check tests passed.'
}
finally {
    $roots | ForEach-Object { Remove-Item -LiteralPath $_ -Recurse -Force }
}
