#Requires -Version 7
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory)]
    [ValidateSet('init', 'list', 'add', 'remove', 'update')]
    [string]$Command,

    [string]$ManifestPath,
    [string]$Name,
    [string]$Path,
    [string]$Build,
    [string]$Install,
    [string]$InstallDir,
    [string[]]$Only,
    [switch]$SkipPull,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$schemaVersion = 1

function Get-ManifestPath {
    if ($ManifestPath) { return [IO.Path]::GetFullPath($ManifestPath) }
    if ($env:AN_DR_TOOLS_MANIFEST) { return [IO.Path]::GetFullPath($env:AN_DR_TOOLS_MANIFEST) }
    return [IO.Path]::GetFullPath((Join-Path $HOME '.an-dr/tools.json'))
}

function Read-Manifest {
    param([Parameter(Mandatory)][string]$FilePath)

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        throw "No tools manifest at $FilePath. Run this script with 'init' first."
    }
    try {
        $raw = Get-Content -LiteralPath $FilePath -Raw | ConvertFrom-Json
    }
    catch {
        throw "Tools manifest at $FilePath is not valid JSON: $($_.Exception.Message)"
    }
    if (-not $raw.PSObject.Properties['tools']) {
        throw "Tools manifest at $FilePath has no 'tools' array."
    }

    $tools = @()
    foreach ($entry in @($raw.tools)) {
        if (-not $entry.PSObject.Properties['name'] -or -not $entry.name) {
            throw "Tools manifest at $FilePath has an entry without a name."
        }
        if (-not $entry.PSObject.Properties['path'] -or -not $entry.path) {
            throw "Tool '$($entry.name)' has no path."
        }
        $tools += [ordered]@{
            name       = [string]$entry.name
            path       = [string]$entry.path
            build      = if ($entry.PSObject.Properties['build']) { [string]$entry.build } else { '' }
            install    = if ($entry.PSObject.Properties['install']) { [string]$entry.install } else { '' }
            installDir = if ($entry.PSObject.Properties['installDir']) { [string]$entry.installDir } else { '' }
        }
    }
    return [ordered]@{ schemaVersion = $schemaVersion; tools = $tools }
}

function Write-Manifest {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)]$Manifest
    )

    $Manifest.tools = @($Manifest.tools | Sort-Object { $_.name })
    $directory = Split-Path -Parent $FilePath
    if ($directory) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }
    $json = $Manifest | ConvertTo-Json -Depth 5
    Set-Content -LiteralPath $FilePath -Value $json -Encoding utf8NoBOM
}

function Resolve-ToolPath {
    param([Parameter(Mandatory)][string]$Candidate)

    $full = [IO.Path]::GetFullPath($Candidate)
    if (-not (Test-Path -LiteralPath $full -PathType Container)) {
        throw "Tool path does not exist: $full"
    }
    git -C $full rev-parse --show-toplevel *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Tool path is not inside a Git repository: $full"
    }
    return $full
}

function Select-Tools {
    param([Parameter(Mandatory)]$Manifest)

    if (-not $Only) { return @($Manifest.tools) }
    $selected = @()
    foreach ($wanted in $Only) {
        $match = @($Manifest.tools | Where-Object { $_.name -eq $wanted })
        if (-not $match) { throw "No tool named '$wanted' in the manifest." }
        $selected += $match[0]
    }
    return $selected
}

function Invoke-ToolCommand {
    param(
        [Parameter(Mandatory)][string]$WorkingDirectory,
        [Parameter(Mandatory)][string]$CommandLine,
        [Parameter(Mandatory)][string]$Label,
        [Parameter(Mandatory)]$Tool
    )

    Write-Host "[$($Tool.name)] $Label -> $CommandLine"
    $previous = @{
        name       = $env:AN_DR_TOOL_NAME
        path       = $env:AN_DR_TOOL_PATH
        installDir = $env:AN_DR_TOOL_INSTALL_DIR
    }
    $env:AN_DR_TOOL_NAME = $Tool.name
    $env:AN_DR_TOOL_PATH = $WorkingDirectory
    $env:AN_DR_TOOL_INSTALL_DIR = $Tool.installDir
    Push-Location -LiteralPath $WorkingDirectory
    try {
        pwsh -NoProfile -Command $CommandLine | Out-Host
        $code = $LASTEXITCODE
    }
    finally {
        Pop-Location
        $env:AN_DR_TOOL_NAME = $previous.name
        $env:AN_DR_TOOL_PATH = $previous.path
        $env:AN_DR_TOOL_INSTALL_DIR = $previous.installDir
    }
    if ($code -ne 0) {
        throw "$Label failed with exit code $code."
    }
}

function Update-Tool {
    param([Parameter(Mandatory)]$Tool)

    $record = [ordered]@{
        name      = $Tool.name
        pulled    = 'skipped'
        built     = 'skipped'
        installed = 'skipped'
        status    = 'ok'
        detail    = ''
    }
    try {
        $path = Resolve-ToolPath -Candidate $Tool.path

        if (-not $SkipPull) {
            $status = git -C $path status --porcelain
            if ($LASTEXITCODE -ne 0) { throw 'git status failed.' }
            if ($status) {
                $record.pulled = 'skipped'
                $record.detail = 'uncommitted changes; pull skipped'
            }
            else {
                Write-Host "[$($Tool.name)] pull"
                git -C $path pull --ff-only 2>&1 | Out-Host
                if ($LASTEXITCODE -ne 0) { throw 'git pull --ff-only failed.' }
                $record.pulled = 'ok'
            }
        }

        if ($Tool.build) {
            Invoke-ToolCommand -WorkingDirectory $path -CommandLine $Tool.build -Label 'build' -Tool $Tool
            $record.built = 'ok'
        }

        if ($Tool.install) {
            if ($Tool.installDir) {
                New-Item -ItemType Directory -Force -Path $Tool.installDir | Out-Null
            }
            Invoke-ToolCommand -WorkingDirectory $path -CommandLine $Tool.install -Label 'install' -Tool $Tool
            $record.installed = 'ok'
        }
    }
    catch {
        $record.status = 'failed'
        $record.detail = $_.Exception.Message
    }
    return [pscustomobject]$record
}

$manifestFile = Get-ManifestPath

switch ($Command) {
    'init' {
        if ((Test-Path -LiteralPath $manifestFile -PathType Leaf) -and -not $Force) {
            throw "Tools manifest already exists at $manifestFile. Use -Force to overwrite it."
        }
        Write-Manifest -FilePath $manifestFile -Manifest ([ordered]@{ schemaVersion = $schemaVersion; tools = @() })
        Write-Output "Created $manifestFile"
    }

    'list' {
        $manifest = Read-Manifest -FilePath $manifestFile
        Write-Output "Manifest: $manifestFile"
        if (-not $manifest.tools) {
            Write-Output 'No tools registered.'
            break
        }
        $manifest.tools | ForEach-Object { [pscustomobject]$_ } | Format-Table -AutoSize | Out-String | Write-Output
    }

    'add' {
        if (-not $Name) { throw 'add requires -Name.' }
        if (-not $Path) { throw 'add requires -Path.' }
        $manifest = Read-Manifest -FilePath $manifestFile
        $existing = @($manifest.tools | Where-Object { $_.name -eq $Name })
        if ($existing -and -not $Force) {
            throw "Tool '$Name' is already registered. Use -Force to replace it."
        }
        $entry = [ordered]@{
            name       = $Name
            path       = Resolve-ToolPath -Candidate $Path
            build      = $Build
            install    = $Install
            installDir = if ($InstallDir) { [IO.Path]::GetFullPath($InstallDir) } else { '' }
        }
        $manifest.tools = @($manifest.tools | Where-Object { $_.name -ne $Name }) + $entry
        Write-Manifest -FilePath $manifestFile -Manifest $manifest
        Write-Output "Registered '$Name' in $manifestFile"
    }

    'remove' {
        if (-not $Name) { throw 'remove requires -Name.' }
        $manifest = Read-Manifest -FilePath $manifestFile
        if (-not @($manifest.tools | Where-Object { $_.name -eq $Name })) {
            throw "No tool named '$Name' in the manifest."
        }
        $manifest.tools = @($manifest.tools | Where-Object { $_.name -ne $Name })
        Write-Manifest -FilePath $manifestFile -Manifest $manifest
        Write-Output "Removed '$Name' from $manifestFile"
    }

    'update' {
        $manifest = Read-Manifest -FilePath $manifestFile
        $targets = Select-Tools -Manifest $manifest
        if (-not $targets) {
            Write-Output 'No tools registered.'
            break
        }
        $results = foreach ($tool in $targets) { Update-Tool -Tool $tool }
        $results | Format-Table -AutoSize | Out-String | Write-Output
        if (@($results | Where-Object { $_.status -eq 'failed' })) {
            exit 1
        }
    }
}
