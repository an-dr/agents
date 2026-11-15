#Requires -Version 7
<#
.SYNOPSIS
Reads and writes tmp-agent-wip.json, the work-in-progress data of the current operation.

.DESCRIPTION
The file sits at the repository root as { schemaVersion, sections }. Each
section belongs to one skill, which alone writes it, and lists the fields it may
hold and the fields each other skill may read; sections.json beside this script
is that register. Anything outside it is refused, so no skill can grow a field
another one does not know about.

  get    -Section <s> [-Field <f>] -Reader <skill>   prints JSON, or null when absent
  set    -Section <s> -Owner <skill> -JsonPath <file> replaces the section
  remove -Section <s> -Owner <skill>                  deletes it, and the file when empty
  path                                                prints the file's path
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, Mandatory)][ValidateSet('get', 'set', 'remove', 'path')][string]$Command,
    [string]$Section,
    [string]$Field,
    [string]$Owner,
    [string]$Reader,
    [string]$JsonPath,
    [string]$Root
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $Root) {
    $Root = (@(& git rev-parse --show-toplevel 2>$null) -join '').Trim()
    if (-not $Root) { throw 'Run inside a git repository or pass -Root.' }
}
$file = Join-Path $Root 'tmp-agent-wip.json'
if ($Command -eq 'path') { Write-Output $file; return }

$register = Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'sections.json') | ConvertFrom-Json
if (-not $Section) { throw "-Section is required for $Command." }
if (-not $register.PSObject.Properties[$Section]) {
    throw "Unknown section '$Section'; the register knows: $(@($register.PSObject.Properties.Name) -join ', ')."
}
$entry = $register.$Section

function Read-WipFile {
    if (-not (Test-Path -LiteralPath $file)) { return [pscustomobject]@{ schemaVersion = 1; sections = [pscustomobject]@{} } }
    $data = Get-Content -Raw -LiteralPath $file | ConvertFrom-Json
    if ($data.schemaVersion -ne 1) { throw "Unsupported tmp-agent-wip.json schema version '$($data.schemaVersion)'." }
    return $data
}

function Write-WipFile([object]$Data) {
    $temporary = Join-Path $Root ('.tmp-agent-wip-{0}.json' -f [guid]::NewGuid())
    try {
        [IO.File]::WriteAllText($temporary, ($Data | ConvertTo-Json -Depth 16), [Text.UTF8Encoding]::new($false))
        [IO.File]::Move($temporary, $file, $true)
    }
    finally { Remove-Item -Force -LiteralPath $temporary -ErrorAction SilentlyContinue }
}

function Assert-Owner {
    if ($Owner -ne $entry.owner) { throw "Section '$Section' belongs to $($entry.owner); '$Owner' may not write it." }
}

switch ($Command) {
    'get' {
        if (-not $Reader) { throw '-Reader is required for get: the skill that reads.' }
        $allowed = if ($Reader -eq $entry.owner) { @($entry.fields) }
            elseif ($entry.readers.PSObject.Properties[$Reader]) { @($entry.readers.$Reader) }
            else { throw "$Reader may not read section '$Section'." }
        if ($Field -and $Field -notin $allowed) { throw "$Reader may not read '$Section.$Field'; it may read: $($allowed -join ', ')." }
        if (-not $Field -and $Reader -ne $entry.owner) { throw "$Reader reads named fields of '$Section' only: $($allowed -join ', ')." }
        $data = Read-WipFile
        $value = if ($data.sections.PSObject.Properties[$Section]) { $data.sections.$Section } else { $null }
        if ($Field) { $value = if ($null -ne $value -and $value.PSObject.Properties[$Field]) { $value.$Field } else { $null } }
        Write-Output (ConvertTo-Json -InputObject $value -Depth 16 -Compress)
    }
    'set' {
        Assert-Owner
        if (-not $JsonPath) { throw '-JsonPath is required for set: a file holding the section as JSON.' }
        $value = Get-Content -Raw -LiteralPath $JsonPath | ConvertFrom-Json
        $unknown = @($value.PSObject.Properties.Name | Where-Object { $_ -notin @($entry.fields) })
        if ($unknown.Count -gt 0) { throw "Section '$Section' has no field(s) $($unknown -join ', '); add them to the register first." }
        $data = Read-WipFile
        $data.sections | Add-Member -NotePropertyName $Section -NotePropertyValue $value -Force
        Write-WipFile $data
    }
    'remove' {
        Assert-Owner
        $data = Read-WipFile
        if ($data.sections.PSObject.Properties[$Section]) { $data.sections.PSObject.Properties.Remove($Section) }
        if (@($data.sections.PSObject.Properties).Count -eq 0) { Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue }
        else { Write-WipFile $data }
    }
}
