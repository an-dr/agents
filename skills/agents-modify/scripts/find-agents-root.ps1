#Requires -Version 7
<#
    Locates the agents clone an instruction change must land in and reports its
    git state. Exits 0 when exactly one clone resolves, 1 when none is found,
    and 2 when several distinct clones are candidates.
#>
[CmdletBinding()]
param(
    [string]$Path = '.',
    [string]$AgentsRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

function Get-FullPath {
    <# Normalizes a path without requiring it to exist. #>
    param([Parameter(Mandatory)][string]$Candidate)

    return ([IO.Path]::GetFullPath($Candidate)).TrimEnd('\', '/')
}

function Test-SameDirectory {
    <# Compares two paths for equality, ignoring case and trailing separators. #>
    param([string]$Left, [string]$Right)

    if (-not $Left -or -not $Right) { return $false }
    return [string]::Equals((Get-FullPath $Left), (Get-FullPath $Right), 'OrdinalIgnoreCase')
}

function Test-AgentsClone {
    <# Reports whether a directory is a clone of the agents repository. #>
    param([string]$Candidate)

    if ([string]::IsNullOrWhiteSpace($Candidate)) { return $false }
    foreach ($required in @('AGENTS.md', 'skills/dev-workflow/SKILL.md')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Candidate $required))) { return $false }
    }
    return $true
}

function Get-LinkTarget {
    <# Returns the target of a directory link, or $null for a real directory. #>
    param([Parameter(Mandatory)][string]$LinkPath)

    if (-not (Test-Path -LiteralPath $LinkPath)) { return $null }
    $item = Get-Item -LiteralPath $LinkPath -Force
    if ($item.LinkType -notin @('Junction', 'SymbolicLink')) { return $null }

    $target = @($item.Target)[0]
    if (-not $target) { return $null }
    return Get-FullPath $target
}

function Get-RepositoryRoot {
    <# Walks up from a directory to the nearest working tree, submodules included. #>
    param([Parameter(Mandatory)][string]$Start)

    if (-not (Test-Path -LiteralPath $Start)) { return $null }
    $directory = Get-FullPath (Resolve-Path -LiteralPath $Start).ProviderPath
    while ($directory) {
        if (Test-Path -LiteralPath (Join-Path $directory '.git')) { return $directory }
        $parent = Split-Path -Parent $directory
        if (-not $parent -or (Test-SameDirectory $parent $directory)) { return $null }
        $directory = $parent
    }
    return $null
}

function Invoke-GitAt {
    <# Runs Git in a repository, returning its output lines or $null on failure. #>
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string[]]$Arguments
    )

    $output = @(& git -C $Root @Arguments 2>$null)
    if ($LASTEXITCODE -ne 0) { return $null }
    return $output
}

$candidates = [System.Collections.Generic.List[object]]::new()

function Add-Candidate {
    <# Records one located directory, whether or not it turns out to be a clone. #>
    param(
        [Parameter(Mandatory)][string]$Source,
        [string]$Candidate
    )

    if ([string]::IsNullOrWhiteSpace($Candidate)) { return }
    if (-not (Test-Path -LiteralPath $Candidate)) { return }

    $full = Get-FullPath (Resolve-Path -LiteralPath $Candidate).ProviderPath
    foreach ($known in $candidates) {
        if ($known.Source -eq $Source -and (Test-SameDirectory $known.Path $full)) { return }
    }
    $candidates.Add([pscustomobject]@{
            Source = $Source
            Path   = $full
            Clone  = (Test-AgentsClone $full)
        })
}

# An explicit path wins over every detected one.
if ($AgentsRoot) { Add-Candidate -Source 'parameter' -Candidate $AgentsRoot }

# The clone providing this script, followed through the junction of a global install.
$skillDirectory = Split-Path -Parent $PSScriptRoot
$skillTarget = Get-LinkTarget -LinkPath $skillDirectory
if (-not $skillTarget) { $skillTarget = $skillDirectory }
Add-Candidate -Source 'self' -Candidate (Join-Path $skillTarget '..\..')

# The repository being worked in, and any agents submodule inside it.
$hostRoot = Get-RepositoryRoot -Start $Path
if ($hostRoot) {
    Add-Candidate -Source 'working-tree' -Candidate $hostRoot
    Add-Candidate -Source 'submodule' -Candidate (Join-Path $hostRoot 'agents')
}

# The clone each AI tool loads globally, read from its agents-install block.
$module = Join-Path $PSScriptRoot '..\..\agents-install\scripts\Install.Common.psm1'
if (Test-Path -LiteralPath $module) {
    Import-Module $module -Force
    $marker = Get-AgentsBlockMarker
    $blockPattern = [regex]::Escape($marker.Begin) + '(?<block>.*?)' + [regex]::Escape($marker.End)
    foreach ($tool in (Get-AgentsToolTarget)) {
        if (-not (Test-Path -LiteralPath $tool.Instructions)) { continue }
        $text = Get-Content -LiteralPath $tool.Instructions -Raw
        if ($null -eq $text) { continue }
        $block = [regex]::Match($text, $blockPattern, 'Singleline')
        if (-not $block.Success) { continue }
        $policy = [regex]::Match($block.Groups['block'].Value, '[@`](?<root>[^\s`]+)/AGENTS\.md')
        if ($policy.Success) {
            Add-Candidate -Source "global:$($tool.Id)" -Candidate $policy.Groups['root'].Value
        }
    }
}

Write-Output '| Source | Path | Clone |'
Write-Output '| --- | --- | --- |'
foreach ($candidate in $candidates) {
    Write-Output ('| {0} | `{1}` | {2} |' -f $candidate.Source, $candidate.Path, $(if ($candidate.Clone) { 'yes' } else { 'no' }))
}
if ($candidates.Count -eq 0) {
    Write-Output '| — | — | — |'
}
Write-Output ''

if ($AgentsRoot -and -not (Test-AgentsClone (Get-FullPath $AgentsRoot))) {
    Write-Output "-AgentsRoot '$AgentsRoot' is not an agents clone; it needs AGENTS.md and skills/dev-workflow/SKILL.md."
    exit 1
}

$clones = @($candidates | Where-Object { $_.Clone })
if ($clones.Count -eq 0) {
    Write-Output 'No agents clone found. Pass -AgentsRoot with the path to one, or clone the repository first.'
    exit 1
}

$fromParameter = @($clones | Where-Object { $_.Source -eq 'parameter' })
if ($fromParameter.Count -gt 0) {
    $root = $fromParameter[0].Path
}
else {
    $distinct = @($clones | Group-Object { $_.Path.ToLowerInvariant() })
    if ($distinct.Count -gt 1) {
        Write-Output "Found $($distinct.Count) different agents clones. Ask the user which one to change, then re-run with -AgentsRoot."
        exit 2
    }
    $root = $distinct[0].Group[0].Path
}

$notes = [System.Collections.Generic.List[string]]::new()
Write-Output '| Fact | Value |'
Write-Output '| --- | --- |'
Write-Output ('| root | `{0}` |' -f $root)

if ($null -eq (Invoke-GitAt -Root $root -Arguments @('rev-parse', '--git-dir'))) {
    Write-Output '| git | not a working tree |'
    $notes.Add('The clone is not a git working tree, so the change cannot be committed there.')
}
else {
    $branch = (@(Invoke-GitAt -Root $root -Arguments @('branch', '--show-current')) -join '').Trim()
    if (-not $branch) {
        Write-Output '| branch | detached HEAD |'
        $notes.Add('HEAD is detached. Check out the default branch before committing, or the commit is unreachable.')
    }
    else {
        Write-Output ('| branch | {0} |' -f $branch)
    }

    $status = @(Invoke-GitAt -Root $root -Arguments @('status', '--porcelain'))
    $changed = @($status | Where-Object { $_ })
    if ($changed.Count -eq 0) {
        Write-Output '| working tree | clean |'
    }
    else {
        Write-Output ('| working tree | {0} changed file(s) |' -f $changed.Count)
        $notes.Add('The clone already has uncommitted changes. Read them before staging, and never commit an unrelated one.')
    }

    $upstream = (@(Invoke-GitAt -Root $root -Arguments @(
                'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{upstream}')) -join '').Trim()
    if (-not $upstream) {
        Write-Output '| upstream | none |'
        $notes.Add('The branch has no upstream, so pushing needs an explicit remote and branch.')
    }
    else {
        $counts = (@(Invoke-GitAt -Root $root -Arguments @(
                    'rev-list', '--left-right', '--count', "HEAD...$upstream")) -join "`t").Split("`t")
        $ahead = if ($counts.Count -ge 1) { $counts[0].Trim() } else { '?' }
        $behind = if ($counts.Count -ge 2) { $counts[1].Trim() } else { '?' }
        Write-Output ('| upstream | {0} (ahead {1}, behind {2}) |' -f $upstream, $ahead, $behind)
    }
}

$nested = $hostRoot -and -not (Test-SameDirectory $hostRoot $root) -and
    $root.StartsWith(($hostRoot + [IO.Path]::DirectorySeparatorChar), [StringComparison]::OrdinalIgnoreCase)
if ($nested) {
    Write-Output ('| nested in | `{0}` |' -f $hostRoot)
    $notes.Add("Committing here moves the gitlink in '$hostRoot'. Leave that pointer change uncommitted and tell the user.")
}
else {
    Write-Output '| nested in | — |'
}

Write-Output ''
foreach ($note in $notes) { Write-Output "- $note" }
if ($notes.Count -gt 0) { Write-Output '' }

Write-Output "Resolved agents root: $root"
