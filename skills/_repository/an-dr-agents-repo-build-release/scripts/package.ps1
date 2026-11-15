#Requires -Version 7
<#
.SYNOPSIS
Packages this repository as agents-<version>.zip, the published release.

.DESCRIPTION
The package is what a user installs: the policy (AGENTS.md), README.md, VERSION,
LICENSE, and every skill except skills/_repository, which only maintains this
repository. With -Tag it refuses a tag that does not name VERSION, so a release
can never carry another version than the one it says. Writes the zip and a
SHA256SUMS line beside it into -OutDirectory and prints the zip's path.
#>
[CmdletBinding()]
param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '../../../..')).Path,
    [string]$OutDirectory = (Join-Path ([IO.Path]::GetTempPath()) 'agents-release'),
    # The release tag, v<version>; checked against VERSION when given.
    [string]$Tag
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$versionFile = Join-Path $Root 'VERSION'
if (-not (Test-Path -LiteralPath $versionFile)) { throw "No VERSION file in '$Root'." }
$version = (Get-Content -Raw -LiteralPath $versionFile).Trim()
if ($version -notmatch '^\d+\.\d+\.\d+$') { throw "VERSION '$version' is not MAJOR.MINOR.PATCH." }
if ($Tag -and $Tag -ne "v$version") { throw "Tag '$Tag' does not match VERSION $version; expected v$version." }
$notes = Join-Path $Root "docs/releases/$version.md"
if ($Tag -and -not (Test-Path -LiteralPath $notes)) { throw "No release notes at docs/releases/$version.md." }

$name = "agents-$version"
$stage = Join-Path ([IO.Path]::GetTempPath()) ("$name-" + [guid]::NewGuid().ToString('N'))
$content = Join-Path $stage $name
New-Item -ItemType Directory -Force -Path $content, $OutDirectory | Out-Null
try {
    foreach ($file in @('AGENTS.md', 'README.md', 'VERSION', 'LICENSE')) {
        Copy-Item -LiteralPath (Join-Path $Root $file) -Destination $content
    }
    $skills = Join-Path $content 'skills'
    New-Item -ItemType Directory -Path $skills | Out-Null
    Copy-Item -LiteralPath (Join-Path $Root 'skills/README.md') -Destination $skills
    foreach ($category in Get-ChildItem -LiteralPath (Join-Path $Root 'skills') -Directory) {
        if ($category.Name -eq '_repository') { continue }
        Copy-Item -LiteralPath $category.FullName -Destination $skills -Recurse
    }
    $zip = Join-Path $OutDirectory "$name.zip"
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    Compress-Archive -Path $content -DestinationPath $zip
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash.ToLowerInvariant()
    Set-Content -LiteralPath (Join-Path $OutDirectory 'SHA256SUMS') -Value "$hash  $name.zip" -NoNewline
    Write-Output $zip
}
finally { Remove-Item -Recurse -Force -LiteralPath $stage -ErrorAction SilentlyContinue }
