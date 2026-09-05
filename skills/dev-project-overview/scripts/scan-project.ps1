#Requires -Version 7
<#
    Collects the evidence a project overview is built from: language weight,
    manifests, entry points and container signals, tests, CI, documentation
    with its staleness, churn hotspots, large files, marker density, and
    author spread. Reports only; changes nothing.
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$Json,
    [int]$Top = 15,
    [int]$ChurnMonths = 12
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $Path).ProviderPath
$excluded = '[\\/](\.git|node_modules|target|dist|build|out|bin|obj|vendor|\.venv|venv|__pycache__|\.next|\.tox|coverage|Pods|third_party)[\\/]'
$binary = '\.(png|jpe?g|gif|ico|svg|pdf|zip|gz|tar|7z|exe|dll|so|dylib|woff2?|ttf|eot|mp4|mp3|wav|bin|lock|snap|pyc|class|jar|db|sqlite3?)$'

function Invoke-Git {
    <# Runs git inside the scanned repository, returning its lines or nothing. #>
    param([Parameter(Mandatory)][string[]]$Argument)

    $output = & git -C $root @Argument 2>$null
    if ($LASTEXITCODE -ne 0) { return @() }
    return @($output)
}

function Write-Section {
    param([Parameter(Mandatory)][string]$Title)

    Write-Host ''
    Write-Host "== $Title" -ForegroundColor Cyan
}

$isRepository = @(Invoke-Git @('rev-parse', '--is-inside-work-tree')).Count -gt 0

$files = @(Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $excluded })
$relative = @{}
foreach ($file in $files) {
    $relative[$file.FullName] = $file.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
}
$paths = @($relative.Values | Sort-Object)

function Measure-Lines {
    param([Parameter(Mandatory)][IO.FileInfo]$File)

    if ($File.Length -gt 2MB) { return 0 }
    try { return @(Get-Content -LiteralPath $File.FullName -ErrorAction Stop).Count }
    catch { return 0 }
}

# ---- languages ------------------------------------------------------------

$languages = @{}
$lineCount = @{}
foreach ($file in $files) {
    $path = $relative[$file.FullName]
    if ($path -match $binary) { continue }
    $extension = if ($file.Extension) { $file.Extension.ToLowerInvariant() } else { '(none)' }
    $lines = Measure-Lines -File $file
    $lineCount[$path] = $lines
    if (-not $languages.ContainsKey($extension)) {
        $languages[$extension] = [pscustomobject]@{ Extension = $extension; Files = 0; Lines = 0 }
    }
    $languages[$extension].Files++
    $languages[$extension].Lines += $lines
}
$languageTable = @($languages.Values | Sort-Object -Property Lines -Descending | Select-Object -First $Top)

# ---- structural signals ---------------------------------------------------

$manifests = @($paths | Where-Object {
        $_ -match '(^|/)(package\.json|Cargo\.toml|pyproject\.toml|setup\.py|requirements[^/]*\.txt|go\.mod|composer\.json|Gemfile|pom\.xml|build\.gradle(\.kts)?|[^/]+\.csproj|[^/]+\.sln|pubspec\.yaml|mix\.exs|CMakeLists\.txt|Makefile)$'
    })
$containerSignals = @($paths | Where-Object {
        $_ -match '(^|/)(Dockerfile[^/]*|docker-compose[^/]*\.ya?ml|Procfile|[^/]*\.tf|Chart\.yaml|skaffold\.ya?ml|serverless\.ya?ml|fly\.toml|vercel\.json|app\.ya?ml)$' -or
        $_ -match '^(deploy|deployment|k8s|kubernetes|helm|infra|charts)/'
    })
# A desktop application, a CLI, or a library deploys nothing and would
# otherwise report no containers at all. Its separately built units are
# declared binaries, packaging scripts, and installers instead.
$packagingSignals = @($paths | Where-Object {
        $_ -match '(^|/)(tauri\.conf\.json|electron-builder\.ya?ml|[^/]*\.spec|[^/]*\.iss|[^/]*\.wxs|Info\.plist|[^/]*\.desktop|snapcraft\.ya?ml|flatpak[^/]*\.ya?ml|PKGBUILD|setup\.iss)$' -or
        $_ -match '(^|/)(dist|install|package|bundle|release)\.(ps1|sh|mjs|js|py)$'
    })
$declaredBinaries = @()
foreach ($manifest in $manifests) {
    $full = Join-Path $root $manifest
    if (-not (Test-Path -LiteralPath $full)) { continue }
    $text = Get-Content -LiteralPath $full -Raw -ErrorAction SilentlyContinue
    if (-not $text) { continue }
    foreach ($match in [regex]::Matches($text, '(?m)^\s*\[\[bin\]\]')) {
        $declaredBinaries += "$manifest (Cargo [[bin]])"
    }
    if ($text -match '"bin"\s*:') { $declaredBinaries += "$manifest (npm bin)" }
    if ($text -match '\[project\.scripts\]') { $declaredBinaries += "$manifest (python script)" }
}
$declaredBinaries = @($declaredBinaries | Group-Object | ForEach-Object { "{0} x{1}" -f $_.Name, $_.Count })
$entryPoints = @($paths | Where-Object {
        $_ -match '(^|/)(main|index|app|program|cli|server|__main__|Program)\.(ts|tsx|js|jsx|mjs|py|go|rs|rb|php|cs|java|kt|swift|c|cc|cpp)$' -or
        $_ -match '^(bin|cmd)/'
    })
$ciFiles = @($paths | Where-Object {
        $_ -match '^\.github/workflows/.+\.ya?ml$' -or
        $_ -match '^(\.gitlab-ci\.yml|azure-pipelines\.yml|\.travis\.yml|Jenkinsfile)$' -or
        $_ -match '^\.circleci/'
    })
$testFiles = @($paths | Where-Object {
        $_ -match '(^|/)(tests?|spec|__tests__)/' -or
        $_ -match '(^|/)[^/]*(_test\.\w+|\.test\.\w+|\.spec\.\w+|Test\.java|Tests\.cs|_spec\.rb)$' -or
        $_ -match '(^|/)test_[^/]+\.py$'
    })
$configFiles = @($paths | Where-Object {
        $_ -match '(^|/)(\.env[^/]*|config[^/]*\.(json|ya?ml|toml|ini)|settings\.(py|json|ya?ml))$'
    })
$sourceFiles = @($paths | Where-Object { $_ -notmatch $binary -and $testFiles -notcontains $_ })
$testRatio = if ($sourceFiles.Count -gt 0) { [Math]::Round($testFiles.Count / [double]$sourceFiles.Count, 3) } else { 0 }

# ---- documentation and its staleness --------------------------------------

$docFiles = @($paths | Where-Object { $_ -match '\.(md|rst|adoc|txt)$' -and $_ -notmatch '^(node_modules|CHANGELOG)' })
$repositoryLastCommit = $null
if ($isRepository) {
    $stamp = @(Invoke-Git @('log', '-1', '--format=%cI'))
    if ($stamp.Count -gt 0) { $repositoryLastCommit = [datetimeoffset]::Parse($stamp[0]) }
}
$documents = foreach ($doc in $docFiles) {
    $lastEdit = $null
    if ($isRepository) {
        $stamp = @(Invoke-Git @('log', '-1', '--format=%cI', '--', $doc))
        if ($stamp.Count -gt 0 -and $stamp[0]) { $lastEdit = [datetimeoffset]::Parse($stamp[0]) }
    }
    $ageDays = if ($lastEdit -and $repositoryLastCommit) { [int]($repositoryLastCommit - $lastEdit).TotalDays } else { -1 }
    [pscustomobject]@{ Path = $doc; LastEdit = if ($lastEdit) { $lastEdit.ToString('yyyy-MM-dd') } else { 'unknown' }; StaleDays = $ageDays }
}
$documents = @($documents | Sort-Object -Property StaleDays -Descending)

# ---- churn, size, markers, authors ----------------------------------------

$churn = @()
if ($isRepository) {
    $since = "$ChurnMonths months ago"
    $touched = @(Invoke-Git @('log', "--since=$since", '--name-only', '--pretty=format:'))
    $counts = @{}
    foreach ($line in $touched) {
        if (-not $line) { continue }
        if ($line -match $excluded -or $line -match $binary) { continue }
        if (-not $counts.ContainsKey($line)) { $counts[$line] = 0 }
        $counts[$line]++
    }
    $churn = @($counts.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First $Top |
            ForEach-Object { [pscustomobject]@{ Path = $_.Key; Commits = $_.Value; Lines = $(if ($lineCount.ContainsKey($_.Key)) { $lineCount[$_.Key] } else { 0 }) } })
}

$largest = @($lineCount.GetEnumerator() | Where-Object { $testFiles -notcontains $_.Key } |
        Sort-Object -Property Value -Descending | Select-Object -First $Top |
        ForEach-Object { [pscustomobject]@{ Path = $_.Key; Lines = $_.Value } })

$markers = @()
$markerMatches = @(Get-ChildItem -LiteralPath $root -Recurse -Force -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $excluded -and $_.Name -notmatch $binary -and $_.Length -le 2MB } |
        Select-String -Pattern '\b(TODO|FIXME|HACK|XXX|DEPRECATED)\b' -ErrorAction SilentlyContinue)
if ($markerMatches) {
    $markers = @($markerMatches | Group-Object -Property { $_.Path.Substring($root.Length).TrimStart('\', '/').Replace('\', '/') } |
            Sort-Object -Property Count -Descending | Select-Object -First $Top |
            ForEach-Object { [pscustomobject]@{ Path = $_.Name; Markers = $_.Count } })
}

$authors = @()
if ($isRepository) {
    $authors = @(Invoke-Git @('shortlog', '-sne', '--all', 'HEAD') | ForEach-Object {
            if ($_ -match '^\s*(\d+)\s+(.+)$') { [pscustomobject]@{ Commits = [int]$Matches[1]; Author = $Matches[2] } }
        } | Select-Object -First $Top)
}

$head = if ($isRepository) { @(Invoke-Git @('rev-parse', '--short', 'HEAD')) | Select-Object -First 1 } else { $null }
$branch = if ($isRepository) { @(Invoke-Git @('rev-parse', '--abbrev-ref', 'HEAD')) | Select-Object -First 1 } else { $null }
$firstCommit = if ($isRepository) { @(Invoke-Git @('log', '--reverse', '--format=%cs')) | Select-Object -First 1 } else { $null }
$totalCommits = if ($isRepository) { @(Invoke-Git @('rev-list', '--count', 'HEAD')) | Select-Object -First 1 } else { $null }

# ---- report ---------------------------------------------------------------

Write-Host "Project scan: $root" -ForegroundColor Green
Write-Host ("commit {0} on {1}; {2} commits since {3}; {4} files, {5} lines" -f
    ($head ?? 'n/a'), ($branch ?? 'n/a'), ($totalCommits ?? '?'), ($firstCommit ?? '?'),
    $paths.Count, (($lineCount.Values | Measure-Object -Sum).Sum))

Write-Section 'Languages'
$languageTable | Format-Table -AutoSize | Out-String -Width 200 | Write-Host

Write-Section 'Manifests'; $manifests | ForEach-Object { Write-Host "  $_" }
Write-Section 'Container signals'; if ($containerSignals) { $containerSignals | ForEach-Object { Write-Host "  $_" } } else { Write-Host '  none found (a desktop app, CLI, or library deploys nothing -- read the packaging signals instead)' }
Write-Section 'Packaging and declared binaries'
if ($packagingSignals -or $declaredBinaries) {
    $packagingSignals | ForEach-Object { Write-Host "  $_" }
    $declaredBinaries | ForEach-Object { Write-Host "  $_" }
} else { Write-Host '  none found' }
Write-Section 'Entry points'; if ($entryPoints) { $entryPoints | Select-Object -First $Top | ForEach-Object { Write-Host "  $_" } } else { Write-Host '  none found' }
Write-Section 'CI'; if ($ciFiles) { $ciFiles | ForEach-Object { Write-Host "  $_" } } else { Write-Host '  none found' }
Write-Section 'Configuration'; if ($configFiles) { $configFiles | Select-Object -First $Top | ForEach-Object { Write-Host "  $_" } } else { Write-Host '  none found' }
Write-Section 'Tests'
Write-Host ("  {0} test files against {1} source files (ratio {2})" -f $testFiles.Count, $sourceFiles.Count, $testRatio)

Write-Section 'Documentation by staleness (days behind the last commit)'
$documents | Select-Object -First $Top | Format-Table -AutoSize | Out-String -Width 200 | Write-Host

Write-Section "Churn hotspots (last $ChurnMonths months)"
if ($churn) { $churn | Format-Table -AutoSize | Out-String -Width 200 | Write-Host } else { Write-Host '  no history available' }

Write-Section 'Largest source files'
$largest | Format-Table -AutoSize | Out-String -Width 200 | Write-Host

Write-Section 'Marker density'
if ($markers) { $markers | Format-Table -AutoSize | Out-String -Width 200 | Write-Host } else { Write-Host '  none found' }

Write-Section 'Authors'
if ($authors) { $authors | Format-Table -AutoSize | Out-String -Width 200 | Write-Host } else { Write-Host '  no history available' }

Write-Host ''
Write-Host 'Read the churn list and the stale documents first: drift and risk concentrate there.' -ForegroundColor Yellow

if ($Json) {
    $report = [ordered]@{
        root = $root; head = $head; branch = $branch; commits = $totalCommits; firstCommit = $firstCommit
        files = $paths.Count; lines = ($lineCount.Values | Measure-Object -Sum).Sum
        languages = $languageTable; manifests = $manifests; containerSignals = $containerSignals
        entryPoints = $entryPoints; packaging = $packagingSignals; binaries = $declaredBinaries; ci = $ciFiles; configuration = $configFiles
        tests = [ordered]@{ files = $testFiles.Count; sources = $sourceFiles.Count; ratio = $testRatio }
        documents = $documents; churn = $churn; largest = $largest; markers = $markers; authors = $authors
    }
    $report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Json -Encoding utf8
    Write-Host "JSON report written to $Json"
}
