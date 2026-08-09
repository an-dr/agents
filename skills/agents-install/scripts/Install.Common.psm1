Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:BeginMarker = '<!-- BEGIN agents-install -->'
$script:EndMarker = '<!-- END agents-install -->'

function Get-AgentsBlockMarker {
    <# Returns the managed-block delimiters shared by install and verify. #>
    return [pscustomobject]@{ Begin = $script:BeginMarker; End = $script:EndMarker }
}

function Resolve-AgentsRoot {
    <# Resolves the agents clone root, defaulting to this script's repository. #>
    param([string]$RequestedRoot)

    $candidate = if ($RequestedRoot) { $RequestedRoot } else { Join-Path $PSScriptRoot '..\..\..' }
    if (-not (Test-Path -LiteralPath $candidate)) {
        throw "Agents root '$candidate' does not exist."
    }
    $root = (Resolve-Path -LiteralPath $candidate).ProviderPath.TrimEnd('\', '/')

    foreach ($required in @('AGENTS.md', 'skills')) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $required))) {
            throw "Agents root '$root' has no '$required'; point -AgentsRoot at a clone of the agents repository."
        }
    }
    return $root
}

function Get-AgentsToolTarget {
    <# Describes each supported tool's global instruction file and skills directory. #>
    param([string[]]$Only)

    $profileDir = [Environment]::GetFolderPath('UserProfile')
    $all = @(
        [pscustomobject]@{
            Id             = 'claude'
            Name           = 'Claude Code'
            Home           = Join-Path $profileDir '.claude'
            Instructions   = Join-Path $profileDir '.claude\CLAUDE.md'
            SkillsDir      = Join-Path $profileDir '.claude\skills'
            SupportsImport = $true
        }
        [pscustomobject]@{
            Id             = 'codex'
            Name           = 'Codex'
            Home           = Join-Path $profileDir '.codex'
            Instructions   = Join-Path $profileDir '.codex\AGENTS.md'
            SkillsDir      = Join-Path $profileDir '.codex\skills'
            SupportsImport = $false
        }
        [pscustomobject]@{
            Id             = 'gemini'
            Name           = 'Gemini CLI'
            Home           = Join-Path $profileDir '.gemini'
            Instructions   = Join-Path $profileDir '.gemini\GEMINI.md'
            SkillsDir      = $null
            SupportsImport = $false
        }
        [pscustomobject]@{
            Id             = 'opencode'
            Name           = 'opencode'
            Home           = Join-Path $profileDir '.config\opencode'
            Instructions   = Join-Path $profileDir '.config\opencode\AGENTS.md'
            SkillsDir      = $null
            SupportsImport = $false
        }
    )

    if ($Only) {
        $selected = @($all | Where-Object { $Only -contains $_.Id })
        $unknown = @($Only | Where-Object { $all.Id -notcontains $_ })
        if ($unknown) {
            throw "Unknown tool id(s): $($unknown -join ', '). Known ids: $($all.Id -join ', ')."
        }
        return $selected
    }
    return @($all | Where-Object { Test-Path -LiteralPath $_.Home })
}

function Get-AgentsSkill {
    <# Lists every skill directory in the clone that actually holds a SKILL.md. #>
    param([Parameter(Mandatory)][string]$AgentsRoot)

    $skillsDir = Join-Path $AgentsRoot 'skills'
    return @(
        Get-ChildItem -LiteralPath $skillsDir -Directory |
            Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'SKILL.md') } |
            Sort-Object Name
    )
}

function Build-AgentsBlock {
    <# Builds the managed instruction block for one tool. #>
    param(
        [Parameter(Mandatory)][string]$AgentsRoot,
        [bool]$SupportsImport
    )

    $policyPath = ($AgentsRoot -replace '\\', '/') + '/AGENTS.md'
    $reference = if ($SupportsImport) {
        "Base engineering policy: @$policyPath"
    }
    else {
        "Base engineering policy lives at ``$policyPath``. Read that file before" +
        "`nstarting any task that changes files in an opted-in repository."
    }

    return @"
$($script:BeginMarker)
## Global agent workflow

$reference

Engage that policy only when the current repository opts in — any of:

- a root ``AGENTS.md`` or ``CLAUDE.md`` that references it;
- an existing ``.progress/workflow.json``;
- the user naming a flow (Quick, Detailed, Detailed Auto) or one of its skills.

Otherwise its skills stay available on request, but do not propose a flow,
create a branch, or write ``.progress/``.
$($script:EndMarker)
"@
}

function Set-AgentsManagedBlock {
    <#
      Writes the managed block into a file, replacing an existing block and
      leaving all surrounding content untouched. Returns created/updated/current.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Block
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        Set-Content -LiteralPath $Path -Value ($Block + "`n") -Encoding utf8
        return 'created'
    }

    $existing = Get-Content -LiteralPath $Path -Raw
    if ($null -eq $existing) { $existing = '' }

    $pattern = [regex]::Escape($script:BeginMarker) + '.*?' + [regex]::Escape($script:EndMarker)
    $regex = [regex]::new($pattern, 'Singleline')
    if ($regex.IsMatch($existing)) {
        if ($regex.Match($existing).Value -eq $Block) { return 'current' }
        $updated = $regex.Replace($existing, [System.Text.RegularExpressions.MatchEvaluator] { param($m) $Block }, 1)
        Set-Content -LiteralPath $Path -Value $updated -NoNewline -Encoding utf8
        return 'updated'
    }

    $updated = $existing.TrimEnd() + "`n`n" + $Block + "`n"
    Set-Content -LiteralPath $Path -Value $updated -NoNewline -Encoding utf8
    return 'created'
}

function Remove-AgentsManagedBlock {
    <# Removes the managed block from a file, keeping any other content. #>
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return 'absent' }

    $existing = Get-Content -LiteralPath $Path -Raw
    if ($null -eq $existing) { return 'absent' }

    $pattern = [regex]::Escape($script:BeginMarker) + '.*?' + [regex]::Escape($script:EndMarker)
    $regex = [regex]::new($pattern, 'Singleline')
    if (-not $regex.IsMatch($existing)) { return 'absent' }

    $remainder = $regex.Replace($existing, '', 1).Trim()
    if ($remainder) {
        Set-Content -LiteralPath $Path -Value ($remainder + "`n") -NoNewline -Encoding utf8
    }
    else {
        Remove-Item -LiteralPath $Path -Force
    }
    return 'removed'
}

function Get-DirectoryLinkTarget {
    <# Returns the resolved target of a directory link, or $null for a real directory. #>
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.LinkType -notin @('Junction', 'SymbolicLink')) { return $null }

    $target = @($item.Target)[0]
    if (-not $target) { return $null }
    return ([System.IO.Path]::GetFullPath($target)).TrimEnd('\', '/')
}

function Test-SamePath {
    <# Compares two paths for equality, ignoring case and trailing separators. #>
    param([string]$Left, [string]$Right)

    if (-not $Left -or -not $Right) { return $false }
    $normalize = { param($p) ([System.IO.Path]::GetFullPath($p)).TrimEnd('\', '/') }
    return [string]::Equals((& $normalize $Left), (& $normalize $Right), 'OrdinalIgnoreCase')
}

function Set-DirectoryLink {
    <#
      Points a directory junction at a target. Returns current/created/replaced,
      or conflict when a real directory occupies the path and -Force is absent.
    #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Target,
        [switch]$Force
    )

    if (Test-Path -LiteralPath $Path) {
        $linkTarget = Get-DirectoryLinkTarget -Path $Path
        if ($linkTarget) {
            if (Test-SamePath -Left $linkTarget -Right $Target) { return 'current' }
            [System.IO.Directory]::Delete($Path)
            New-Item -ItemType Junction -Path $Path -Target $Target | Out-Null
            return 'replaced'
        }
        if (-not $Force) { return 'conflict' }
        Remove-Item -LiteralPath $Path -Recurse -Force
    }

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    New-Item -ItemType Junction -Path $Path -Target $Target | Out-Null
    return 'created'
}

function Remove-DirectoryLink {
    <# Deletes a directory link, refusing to touch a real directory. #>
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) { return 'absent' }
    if (-not (Get-DirectoryLinkTarget -Path $Path)) { return 'not-a-link' }
    [System.IO.Directory]::Delete($Path)
    return 'removed'
}

function Remove-StaleAgentsLink {
    <#
      Deletes links into the agents clone whose skill no longer exists, which is
      what a rename leaves behind. Links pointing anywhere else are never touched.
    #>
    param(
        [Parameter(Mandatory)][string]$SkillsDirectory,
        [Parameter(Mandatory)][string]$AgentsRoot,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$CurrentSkill
    )

    if (-not (Test-Path -LiteralPath $SkillsDirectory)) { return @() }

    $skillsRoot = ([System.IO.Path]::GetFullPath((Join-Path $AgentsRoot 'skills'))).TrimEnd('\', '/')
    $removed = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in Get-ChildItem -LiteralPath $SkillsDirectory -Directory -Force) {
        if ($CurrentSkill -contains $entry.Name) { continue }
        $target = Get-DirectoryLinkTarget -Path $entry.FullName
        if (-not $target) { continue }
        if (-not $target.StartsWith($skillsRoot, [StringComparison]::OrdinalIgnoreCase)) { continue }
        [System.IO.Directory]::Delete($entry.FullName)
        $removed.Add($entry.Name)
    }
    return $removed.ToArray()
}

Export-ModuleMember -Function @(
    'Get-AgentsBlockMarker',
    'Resolve-AgentsRoot',
    'Get-AgentsToolTarget',
    'Get-AgentsSkill',
    'Build-AgentsBlock',
    'Set-AgentsManagedBlock',
    'Remove-AgentsManagedBlock',
    'Get-DirectoryLinkTarget',
    'Test-SamePath',
    'Set-DirectoryLink',
    'Remove-DirectoryLink',
    'Remove-StaleAgentsLink'
)
