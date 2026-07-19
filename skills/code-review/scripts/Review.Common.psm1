Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ReviewRepositoryRoot {
    <# Returns the root of the repository being reviewed. #>
    $root = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $root) {
        throw 'Run review scripts inside the repository being reviewed.'
    }
    return $root.Trim()
}

function Initialize-ReviewDirectory {
    <# Creates REPO/code-review and ensures its managed ignore rules. #>
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $directory = Join-Path $RepositoryRoot 'code-review'
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $ignorePath = Join-Path $directory '.gitignore'
    $requiredLines = @(
        '# Managed code-review artifacts'
        '*.review.json'
        '*.review.md'
        '.review-*.tmp'
    )
    $existingLines = if (Test-Path -LiteralPath $ignorePath) {
        @(Get-Content -LiteralPath $ignorePath)
    }
    else {
        @()
    }
    $missingLines = @($requiredLines | Where-Object { $_ -notin $existingLines })
    if ($missingLines.Count -gt 0) {
        $lines = [Collections.Generic.List[string]]::new()
        foreach ($line in $existingLines) { $lines.Add($line) }
        if ($lines.Count -gt 0 -and $lines[$lines.Count - 1]) { $lines.Add('') }
        foreach ($line in $missingLines) { $lines.Add($line) }
        $lines.Add('')
        [IO.File]::WriteAllText(
            $ignorePath,
            ($lines -join [Environment]::NewLine),
            [Text.UTF8Encoding]::new($false)
        )
    }
    return $directory
}

function ConvertTo-ReviewSlug {
    <# Converts a Git reference into a filesystem-safe review identifier. #>
    param([Parameter(Mandatory)][string]$Value)

    $slug = ($Value.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')
    if (-not $slug) {
        throw "Cannot create a review identifier from '$Value'."
    }
    return $slug
}

function Enter-ReviewLock {
    <# Acquires an exclusive local lock for one canonical review file. #>
    param([Parameter(Mandatory)][string]$Path)

    $fullPath = [IO.Path]::GetFullPath($Path).ToLowerInvariant()
    $bytes = [Text.Encoding]::UTF8.GetBytes($fullPath)
    $hash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
    $lockPath = Join-Path ([IO.Path]::GetTempPath()) "agents-review-$hash.lock"
    try {
        $stream = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None')
    }
    catch {
        throw 'Another process is updating this review. Retry after it finishes.'
    }
    return [pscustomobject]@{ path = $lockPath; stream = $stream }
}

function Exit-ReviewLock {
    <# Releases a lock created by Enter-ReviewLock. #>
    param([Parameter(Mandatory)]$Lock)

    $Lock.stream.Dispose()
    Remove-Item -Force -LiteralPath $Lock.path -ErrorAction SilentlyContinue
}

function Assert-ReviewProperties {
    <# Rejects missing and unknown JSON object properties. #>
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string[]]$Expected,
        [Parameter(Mandatory)][string]$Name
    )

    $actual = @($Object.PSObject.Properties.Name)
    $missing = @($Expected | Where-Object { $_ -notin $actual })
    $unknown = @($actual | Where-Object { $_ -notin $Expected })
    if ($missing.Count -gt 0) {
        throw "$Name is missing properties: $($missing -join ', ')."
    }
    if ($unknown.Count -gt 0) {
        throw "$Name contains unknown properties: $($unknown -join ', ')."
    }
}

function Assert-ReviewNotes {
    <# Validates one numbered finding or positive-note collection. #>
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Notes,
        [Parameter(Mandatory)][string]$Prefix,
        [switch]$Positive
    )

    $expectedNumber = 1
    foreach ($note in $Notes) {
        $expectedProperties = if ($Positive) {
            @('id', 'text', 'addedAt')
        }
        else {
            @('id', 'file', 'line', 'text', 'recommendation', 'addedAt')
        }
        Assert-ReviewProperties -Object $note -Expected $expectedProperties -Name "Review note $expectedNumber"
        $expectedId = "$Prefix.$expectedNumber"
        if ($note.id -ne $expectedId) {
            throw "Expected review note ID '$expectedId', found '$($note.id)'."
        }
        if ([string]::IsNullOrWhiteSpace([string]$note.text)) {
            throw "Review note '$expectedId' has no text."
        }
        Assert-ReviewTimestamp -Value $note.addedAt -Name "$expectedId addedAt"
        if (-not $Positive) {
            if ([string]::IsNullOrWhiteSpace([string]$note.file)) {
                throw "Review finding '$expectedId' has no file."
            }
            $file = ([string]$note.file).Replace('\', '/')
            if ([IO.Path]::IsPathRooted($file) -or @($file.Split('/')).Contains('..')) {
                throw "Review finding '$expectedId' must use a repository-relative file path."
            }
            if ([string]::IsNullOrWhiteSpace([string]$note.recommendation)) {
                throw "Review finding '$expectedId' has no recommendation."
            }
            if ($null -ne $note.line -and [int]$note.line -lt 1) {
                throw "Review finding '$expectedId' has an invalid line number."
            }
        }
        $expectedNumber++
    }
}

function Assert-ReviewTimestamp {
    <# Accepts PowerShell's typed JSON dates or parseable timestamp strings. #>
    param(
        [Parameter(Mandatory)]$Value,
        [Parameter(Mandatory)][string]$Name
    )

    if ($Value -is [datetime] -or $Value -is [datetimeoffset]) {
        return
    }
    $parsed = [datetimeoffset]::MinValue
    if (-not [datetimeoffset]::TryParse(
            [string]$Value,
            [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind,
            [ref]$parsed
        )) {
        throw "Review JSON contains an invalid '$Name' timestamp."
    }
}

function Assert-ReviewJson {
    <# Validates the complete canonical review schema and controlled values. #>
    param([Parameter(Mandatory)]$Review)

    Assert-ReviewProperties -Object $Review -Expected @(
        'schemaVersion', 'reviewId', 'reference', 'scope', 'createdAt',
        'updatedAt', 'summary', 'sections', 'verdict'
    ) -Name 'Review JSON'
    if ($Review.schemaVersion -ne 1) {
        throw "Unsupported review schema version '$($Review.schemaVersion)'."
    }
    foreach ($property in @('reviewId', 'reference', 'scope', 'createdAt', 'updatedAt')) {
        if ([string]::IsNullOrWhiteSpace([string]$Review.$property)) {
            throw "Review JSON is missing '$property'."
        }
    }
    if ($Review.scope -notin @('verify', 'mr', 'requested')) {
        throw "Unsupported review scope '$($Review.scope)'."
    }
    foreach ($timestamp in @('createdAt', 'updatedAt')) {
        Assert-ReviewTimestamp -Value $Review.$timestamp -Name $timestamp
    }
    if ($null -eq $Review.sections -or $null -eq $Review.verdict) {
        throw 'Review JSON is missing sections or verdict.'
    }
    Assert-ReviewProperties -Object $Review.sections -Expected @(
        'critical', 'high', 'improvements', 'positives'
    ) -Name 'Review sections'
    Assert-ReviewProperties -Object $Review.verdict -Expected @(
        'decision', 'rationale'
    ) -Name 'Review verdict'
    foreach ($name in @('critical', 'high', 'improvements', 'positives')) {
        if ($null -eq $Review.sections.$name) {
            throw "Review JSON is missing sections.$name."
        }
    }
    Assert-ReviewNotes -Notes @($Review.sections.critical) -Prefix 'CR'
    Assert-ReviewNotes -Notes @($Review.sections.high) -Prefix 'HI'
    Assert-ReviewNotes -Notes @($Review.sections.improvements) -Prefix 'IM'
    Assert-ReviewNotes -Notes @($Review.sections.positives) -Prefix 'PO' -Positive
    if ($Review.verdict.decision -notin @('pending', 'approve', 'approve-with-comments', 'changes-required')) {
        throw "Unsupported review verdict '$($Review.verdict.decision)'."
    }
    if ($Review.verdict.decision -ne 'pending' -and
        [string]::IsNullOrWhiteSpace([string]$Review.verdict.rationale)) {
        throw 'A completed verdict requires a rationale.'
    }
}

function Read-ReviewJson {
    <# Reads and validates canonical review JSON. #>
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Review JSON does not exist: $Path"
    }
    $review = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    Assert-ReviewJson -Review $review
    $expectedName = "$($review.reviewId).review.json"
    if ((Split-Path -Leaf $Path) -ne $expectedName) {
        throw "Review filename must match reviewId: $expectedName"
    }
    return $review
}

function Resolve-ReviewPath {
    <# Validates that canonical JSON stays directly under REPO/code-review. #>
    param([Parameter(Mandatory)][string]$Path)

    $repositoryRoot = Get-ReviewRepositoryRoot
    $reviewDirectory = Initialize-ReviewDirectory -RepositoryRoot $repositoryRoot
    $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
    if ((Split-Path -Parent $resolvedPath) -ne [IO.Path]::GetFullPath($reviewDirectory)) {
        throw 'Review JSON must be directly inside REPO/code-review/.'
    }
    if (-not $resolvedPath.EndsWith('.review.json', [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Canonical review files must end with .review.json.'
    }
    return $resolvedPath
}

function Write-ReviewJson {
    <# Validates and atomically writes canonical review JSON. #>
    param(
        [Parameter(Mandatory)]$Review,
        [Parameter(Mandatory)][string]$Path
    )

    $Review.updatedAt = (Get-Date).ToUniversalTime().ToString('o')
    Assert-ReviewJson -Review $Review
    $json = $Review | ConvertTo-Json -Depth 10
    Write-ReviewText -Text $json -Path $Path
}

function Write-ReviewText {
    <# Atomically writes a review artifact beside its destination. #>
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text,
        [Parameter(Mandatory)][string]$Path
    )

    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $temporaryPath = Join-Path $directory ('.review-{0}.tmp' -f [guid]::NewGuid())
    try {
        [IO.File]::WriteAllText($temporaryPath, $Text, [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporaryPath, $Path, $true)
    }
    finally {
        Remove-Item -Force -LiteralPath $temporaryPath -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function Assert-ReviewJson, ConvertTo-ReviewSlug,
    Enter-ReviewLock, Exit-ReviewLock, Get-ReviewRepositoryRoot,
    Initialize-ReviewDirectory, Read-ReviewJson, Resolve-ReviewPath,
    Write-ReviewJson, Write-ReviewText
