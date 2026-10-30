#Requires -Version 7
<# Check Git-discoverable Markdown, including new files, without scanning ignored artifacts. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../../..'))
if (-not (Test-Path -LiteralPath (Join-Path $repositoryRoot 'skills/README.md'))) {
    Write-Output 'Repository Markdown checks not applicable outside the source skill repository.'
    return
}
$paths = @(& git -C $repositoryRoot -c core.quotepath=false ls-files --cached --others --exclude-standard -- '*.md')
if ($LASTEXITCODE -ne 0) { throw 'Could not discover repository Markdown files.' }
$files = @($paths | Sort-Object -Unique | ForEach-Object { Join-Path $repositoryRoot $_ } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
if ($files.Count -eq 0) { throw 'No repository Markdown files discovered.' }
& (Join-Path $PSScriptRoot '../check-markdown.ps1') -Path $files
if ($LASTEXITCODE -ne 0) { throw 'Repository Markdown check failed.' }
