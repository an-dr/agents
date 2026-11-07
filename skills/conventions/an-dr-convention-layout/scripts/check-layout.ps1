#Requires -Version 7
<#
    Checks a git repository's tracked files against the shared layout rules:
    README.md and LICENSE at the root, no committed generated folders, plural
    docs and examples folders, and no apps/<name>/ holding a single subfolder.
    Prints one row per finding and exits 1 when any finding is an error.
#>
[CmdletBinding()]
param([string]$Path = '.')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $Path).ProviderPath
$tracked = @(& git -C $root ls-files 2>$null)
if ($LASTEXITCODE -ne 0) { throw "Not a git repository: $root" }

$findings = [Collections.Generic.List[object]]::new()
function Add-Finding([string]$Severity, [string]$Rule, [string]$Where, [string]$Detail) {
    $findings.Add([pscustomobject]@{ Severity = $Severity; Rule = $Rule; Path = $Where; Detail = $Detail })
}

# Root files
$rootFiles = @($tracked | Where-Object { $_ -notmatch '/' })
if ($rootFiles -notcontains 'README.md') { Add-Finding 'error' 'root-file' 'README.md' 'Every repository has README.md at the root.' }
if (-not @($rootFiles | Where-Object { $_ -match '^(LICENSE|LICENCE|COPYING)(\.\w+)?$' }).Count) {
    Add-Finding 'warning' 'root-file' 'LICENSE' 'A published repository has LICENSE at the root.'
}

# Committed generated folders, reported once per folder
$generated = '^(?<folder>(?:[^/]+/)*?(?:\.artifacts|code-review|\.tmp-ai-gen|__pycache__))/'
$tracked | ForEach-Object { if ($_ -match $generated) { "$($Matches['folder'])/" } } | Sort-Object -Unique |
    ForEach-Object { Add-Finding 'error' 'generated-committed' $_ 'Generated files are never committed.' }

# Singular top-level folders
foreach ($singular in @{ 'doc' = 'docs'; 'example' = 'examples' }.GetEnumerator()) {
    if (@($tracked | Where-Object { $_.StartsWith("$($singular.Key)/") }).Count) {
        Add-Finding 'error' 'plural-folder' "$($singular.Key)/" "Use $($singular.Value)/."
    }
}

# apps/<name>/ holding a single subfolder and nothing else
$apps = $tracked | Where-Object { $_ -match '^apps/[^/]+/' } | Group-Object { ($_ -split '/')[1] }
foreach ($app in $apps) {
    $direct = @($app.Group | Where-Object { ($_ -split '/').Count -eq 3 })
    $folders = @($app.Group | Where-Object { ($_ -split '/').Count -gt 3 } | ForEach-Object { ($_ -split '/')[2] } | Sort-Object -Unique)
    if ($direct.Count -eq 0 -and $folders.Count -eq 1) {
        Add-Finding 'error' 'empty-nesting' "apps/$($app.Name)/$($folders[0])/" "Move its content up into apps/$($app.Name)/."
    }
}

if ($findings.Count -eq 0) {
    Write-Output "Layout check passed: $root"
    exit 0
}
Write-Output '| Severity | Rule | Path | Detail |'
Write-Output '| --- | --- | --- | --- |'
$findings | ForEach-Object { Write-Output "| $($_.Severity) | $($_.Rule) | ``$($_.Path)`` | $($_.Detail) |" }
$errors = @($findings | Where-Object Severity -eq 'error').Count
Write-Output "$errors error(s), $($findings.Count - $errors) warning(s)."
if ($errors -gt 0) { exit 1 }
