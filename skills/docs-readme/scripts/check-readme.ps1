#Requires -Version 7
<#
    Reports the repository evidence a README may rely on, then every claim the
    README makes that the evidence does not support. Exits non-zero on a
    contradiction or an unresolved link.
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$Readme = 'README.md'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path -LiteralPath $Path).ProviderPath
$excluded = '[\\/](\.git|node_modules|target|dist|build|vendor|\.venv|__pycache__)[\\/]'
$findings = [Collections.Generic.List[object]]::new()

function Add-Finding {
    param(
        [Parameter(Mandatory)][ValidateSet('error', 'warning', 'note')][string]$Severity,
        [Parameter(Mandatory)][string]$Rule,
        [Parameter(Mandatory)][string]$Detail,
        [int]$Line = 0
    )

    $findings.Add([pscustomobject]@{
            Severity = $Severity; Rule = $Rule; Line = $Line; Detail = $Detail
        })
}

function Get-RepositoryFile {
    <# Lists repository files, skipping dependency and build directories. #>
    param([int]$Depth = 3)

    return @(Get-ChildItem -LiteralPath $root -Recurse -Depth $Depth -Force -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch $excluded })
}

function Test-AnyPath {
    <# Reports whether any of the given repository-relative paths exists. #>
    param([Parameter(Mandatory)][string[]]$Candidate)

    foreach ($item in $Candidate) {
        if (Test-Path -LiteralPath (Join-Path $root $item)) { return $true }
    }
    return $false
}

$files = Get-RepositoryFile
$names = @($files | ForEach-Object { $_.Name })
$relative = @($files | ForEach-Object { $_.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/') })

# ---- evidence -------------------------------------------------------------

$licenseFile = @($names | Where-Object { $_ -match '^(LICENSE|LICENCE|COPYING)(\.\w+)?$' }) | Select-Object -First 1
$manifests = @($relative | Where-Object {
        $_ -match '^[^/]*(package\.json|Cargo\.toml|pyproject\.toml|setup\.py|go\.mod|composer\.json|Gemfile|pom\.xml|build\.gradle(\.kts)?|.*\.csproj)$'
    })
$ciFiles = @($relative | Where-Object {
        $_ -match '^\.github/workflows/.+\.ya?ml$' -or
        $_ -match '^(\.gitlab-ci\.yml|azure-pipelines\.yml|\.travis\.yml|Jenkinsfile)$' -or
        $_ -match '^\.circleci/'
    })
$testEvidence = @($relative | Where-Object {
        $_ -match '(^|/)(tests?|spec|__tests__)/' -or
        $_ -match '(^|/)[^/]*(_test\.\w+|\.test\.\w+|\.spec\.\w+|Test\.java|Tests\.cs)$' -or
        $_ -match '(^|/)test_[^/]+\.py$'
    })
$docsDirectory = Test-AnyPath -Candidate @('docs', 'doc')
$adrDirectory = Test-AnyPath -Candidate @('docs/adr', 'docs/decisions', 'adr')
$contributing = Test-AnyPath -Candidate @('CONTRIBUTING.md', 'CONTRIBUTING', '.github/CONTRIBUTING.md')
$codeOfConduct = Test-AnyPath -Candidate @('CODE_OF_CONDUCT.md', '.github/CODE_OF_CONDUCT.md')
$workspace = @($relative | Where-Object { $_ -match '^(packages|apps|crates|services)/' })
$images = @($relative | Where-Object { $_ -match '\.(png|gif|jpe?g|svg|webp)$' })
$cliHints = @($relative | Where-Object { $_ -match '^(bin|cmd)/' -or $_ -match '(^|/)cli\.\w+$' })

$commitCount = 0
& git -C $root rev-parse --is-inside-work-tree 2>$null | Out-Null
$isRepository = $LASTEXITCODE -eq 0
if ($isRepository) {
    $countText = (@(& git -C $root rev-list --count HEAD 2>$null) -join '').Trim()
    if ($LASTEXITCODE -eq 0 -and $countText) { $commitCount = [int]$countText }
}

Write-Output 'Evidence:'
$evidence = [ordered]@{
    'manifests'      = if ($manifests.Count) { $manifests -join ', ' } else { 'none' }
    'license file'   = if ($licenseFile) { $licenseFile } else { 'none' }
    'CI config'      = if ($ciFiles.Count) { $ciFiles -join ', ' } else { 'none' }
    'tests'          = if ($testEvidence.Count) { "$($testEvidence.Count) file(s)" } else { 'none' }
    'docs directory' = if ($adrDirectory) { 'yes, with ADRs' } elseif ($docsDirectory) { 'yes' } else { 'none' }
    'contributing'   = if ($contributing) { 'yes' } else { 'none' }
    'code of conduct' = if ($codeOfConduct) { 'yes' } else { 'none' }
    'sub-packages'   = if ($workspace.Count) { "yes ($(@($workspace | ForEach-Object { ($_ -split '/')[1] } | Sort-Object -Unique).Count))" } else { 'none' }
    'command entry'  = if ($cliHints.Count) { $cliHints -join ', ' } else { 'none' }
    'images'         = if ($images.Count) { "$($images.Count)" } else { 'none' }
    'commits'        = if ($isRepository) { $commitCount } else { 'not a Git repository' }
}
foreach ($item in $evidence.GetEnumerator()) {
    Write-Output ('  {0,-16} {1}' -f $item.Key, $item.Value)
}

# ---- the README itself ----------------------------------------------------

$readmePath = Join-Path $root $Readme
if (-not (Test-Path -LiteralPath $readmePath)) {
    Write-Output ''
    Write-Output "No $Readme exists. Write one from the evidence above."
    exit 0
}

$lines = @([IO.File]::ReadAllLines($readmePath))
$inFence = $false
$headings = [Collections.Generic.List[object]]::new()
for ($index = 0; $index -lt $lines.Count; $index++) {
    $line = $lines[$index]
    if ($line -match '^\s*```') { $inFence = -not $inFence; continue }
    if ($inFence) { continue }
    if ($line -cmatch '^(?<hashes>#{1,6})\s+(?<text>.+?)\s*$') {
        $headings.Add([pscustomobject]@{
                Level = $Matches['hashes'].Length
                Text  = $Matches['text']
                Line  = $index + 1
            })
    }
}

# Baseline sections, in the order the skill requires them.
$baseline = [ordered]@{
    why           = 'why|about|overview|problem|motivat|rationale'
    install       = 'install|setup|getting.started|prerequisit'
    usage         = 'usage|quick.?start|example|how.to.use'
    features      = 'feature|capabilit|what.it.does'
    configuration = 'config|settings|options|environment'
    documentation = 'document|^docs$|reference|learn.more'
    contributing  = 'contribut|development|hacking'
    license       = 'licen[cs]e'
    status        = 'status|maintenance|project.state|stability|roadmap'
}

$found = [ordered]@{}
foreach ($key in $baseline.Keys) { $found[$key] = $null }
foreach ($heading in $headings) {
    foreach ($key in $baseline.Keys) {
        if ($heading.Text -imatch $baseline[$key] -and -not $found[$key]) {
            $found[$key] = $heading
        }
    }
}

$body = ($lines -join "`n")

# Claims the repository does not support.
if ($found['license'] -and -not $licenseFile) {
    Add-Finding -Severity error -Rule 'claim.license' -Line $found['license'].Line -Detail (
        'The README has a license section but the repository has no LICENSE file. Report the gap instead of naming a license.')
}
if ($testEvidence.Count -eq 0 -and $body -imatch '(?m)^.*\b(run the tests|npm test|pytest|cargo test|go test|dotnet test)\b.*$') {
    Add-Finding -Severity error -Rule 'claim.tests' -Detail (
        'The README explains how to run tests, but no test files were found.')
}
foreach ($match in [regex]::Matches($body, 'actions/workflows/(?<file>[A-Za-z0-9._-]+\.ya?ml)/badge\.svg')) {
    $workflow = ".github/workflows/$($match.Groups['file'].Value)"
    if (-not (Test-AnyPath -Candidate @($workflow))) {
        Add-Finding -Severity error -Rule 'badge.workflow' -Detail (
            "A build badge points at '$workflow', which does not exist.")
    }
}
if ($ciFiles.Count -eq 0 -and $body -imatch '!\[[^\]]*\]\([^)]*(build|ci|workflow|travis|circleci)[^)]*\)') {
    Add-Finding -Severity warning -Rule 'badge.ci' -Detail (
        'The README shows a build badge, but the repository has no CI configuration.')
}

# Links that do not resolve.
$inFence = $false
for ($index = 0; $index -lt $lines.Count; $index++) {
    if ($lines[$index] -match '^\s*```') { $inFence = -not $inFence; continue }
    if ($inFence) { continue }
    foreach ($match in [regex]::Matches($lines[$index], '\]\((?<target>[^)\s]+)')) {
        $target = $match.Groups['target'].Value
        if ($target -match '^(https?:|mailto:|#|<)') { continue }
        $cleaned = ($target -split '#')[0]
        if (-not $cleaned) { continue }
        if (-not (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $readmePath) $cleaned))) {
            Add-Finding -Severity error -Rule 'link.broken' -Line ($index + 1) -Detail (
                "The link target '$cleaned' does not resolve.")
        }
    }
}

# Redundancy and shape.
foreach ($group in ($headings | Group-Object { $_.Text.ToLowerInvariant() } | Where-Object { $_.Count -gt 1 })) {
    $where = ($group.Group | ForEach-Object { $_.Line }) -join ', '
    Add-Finding -Severity warning -Rule 'content.duplicate' -Line $group.Group[0].Line -Detail (
        "The heading '$($group.Group[0].Text)' appears $($group.Count) times (lines $where). One of them is redundant.")
}
if (@($headings | Where-Object { $_.Level -eq 1 }).Count -eq 0) {
    Add-Finding -Severity warning -Rule 'structure.title' -Detail 'The README has no title heading.'
}

$screens = [math]::Ceiling($lines.Count / 45)
$hasToc = $body -imatch '(?m)^#{1,3}\s*(table of contents|contents)\s*$'
if ($screens -gt 4 -and -not $hasToc) {
    Add-Finding -Severity warning -Rule 'structure.toc' -Detail (
        "The README runs about $screens screens and has no table of contents.")
}
if ($screens -le 4 -and $hasToc) {
    Add-Finding -Severity warning -Rule 'structure.toc' -Detail (
        "The README is about $screens screens; a table of contents is noise at that length.")
}

foreach ($key in $baseline.Keys) {
    if ($found[$key]) { continue }
    if ($key -eq 'license' -and -not $licenseFile) {
        Add-Finding -Severity warning -Rule 'gap.license' -Detail (
            'No license section and no LICENSE file. Raise the missing license with the user.')
        continue
    }
    Add-Finding -Severity warning -Rule "missing.$key" -Detail "The baseline '$key' section is absent."
}

$ordered = @($found.Keys | Where-Object { $found[$_] })
$previousLine = 0
$previousKey = ''
foreach ($key in $ordered) {
    if ($found[$key].Line -lt $previousLine) {
        Add-Finding -Severity warning -Rule 'structure.order' -Line $found[$key].Line -Detail (
            "'$key' comes after '$previousKey' in the file but before it in the baseline order.")
    }
    $previousLine = $found[$key].Line
    $previousKey = $key
}

# Conditional modules the evidence supports but the README omits.
if ($testEvidence.Count -gt 0 -and -not $found['contributing'] -and $body -inotmatch '(?m)^#{2,3}.*development') {
    Add-Finding -Severity note -Rule 'module.development' -Detail (
        'The repository has tests but the README never says how to run them.')
}
if ($workspace.Count -gt 0 -and $body -inotmatch '(?m)^#{2,3}.*(repository (map|layout)|project structure|packages)') {
    Add-Finding -Severity note -Rule 'module.map' -Detail (
        'The repository has sub-packages but the README has no repository map.')
}
if ($adrDirectory -and $body -inotmatch 'adr|decision') {
    Add-Finding -Severity note -Rule 'module.adr' -Detail (
        'The repository records ADRs that the README never links to.')
}
if ($images.Count -gt 0 -and $body -inotmatch '!\[') {
    Add-Finding -Severity note -Rule 'module.screenshot' -Detail (
        'The repository contains images that the README never shows.')
}

# ---- report ---------------------------------------------------------------

Write-Output ''
if ($findings.Count -eq 0) {
    Write-Output "$Readme matches the repository evidence and the baseline structure."
    exit 0
}

$rank = @{ error = 0; warning = 1; note = 2 }
foreach ($finding in ($findings | Sort-Object @{ Expression = { $rank[$_.Severity] } }, Line)) {
    Write-Output ('  {0,-7} line {1,-4} {2,-22} {3}' -f
        $finding.Severity, $finding.Line, $finding.Rule, $finding.Detail)
}

$errorCount = @($findings | Where-Object { $_.Severity -eq 'error' }).Count
Write-Output ''
Write-Output "$($findings.Count) finding(s), $errorCount blocking."
if ($errorCount -gt 0) { exit 1 }
