#Requires -Version 7
<#
    Checks the skill scripts against script: every .ps1 starts with
    '#Requires -Version 7', and no script guesses where another skill is installed
    (a skill's folder arrives through a -<Name>Skill parameter instead).
    Prints a Markdown table of problems and exits 1 when there are any.
#>
[CmdletBinding()]
param([string]$Root = (Join-Path $PSScriptRoot '../../../..'))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path -LiteralPath $Root).ProviderPath
$skillsDir = Join-Path $Root 'skills'
$folders = @(Get-ChildItem -Path (Join-Path $skillsDir '*/*') -Directory | Select-Object -ExpandProperty Name)

$problems = [System.Collections.Generic.List[object]]::new()
$siblingPattern = '\.\./\.\./(\.\./)?([a-z_-]+/)?(?<skill>[a-z0-9-]+)'
$scripts = @(Get-ChildItem -LiteralPath $skillsDir -Recurse -File -Include '*.ps1', '*.psm1')

foreach ($folder in Get-ChildItem -Path (Join-Path $skillsDir '*/*/scripts') -Directory) {
    $relative = $folder.FullName.Substring($Root.Length + 1) -replace '\\', '/'
    if (-not (Test-Path -LiteralPath (Join-Path $folder.FullName 'run-tests.ps1') -PathType Leaf)) {
        $problems.Add([pscustomobject]@{ Where = $relative; What = 'missing run-tests.ps1' })
    }
    foreach ($test in Get-ChildItem -LiteralPath $folder.FullName -File -Filter 'test-*.ps1') {
        $problems.Add([pscustomobject]@{ Where = $relative; What = "$($test.Name) belongs in tests/, not scripts/" })
    }
}

foreach ($file in $scripts) {
    $relative = $file.FullName.Substring($Root.Length + 1) -replace '\\', '/'
    $text = [IO.File]::ReadAllText($file.FullName)

    if ($file.Extension -eq '.ps1' -and -not $text.StartsWith('#Requires -Version 7')) {
        $problems.Add([pscustomobject]@{ Where = $relative; What = "does not start with '#Requires -Version 7'" })
    }
    foreach ($match in [regex]::Matches($text, $siblingPattern)) {
        $target = $match.Groups['skill'].Value
        if ($target -in $folders) {
            $problems.Add([pscustomobject]@{ Where = $relative; What = "guesses where $target is installed; take its folder as a -<Name>Skill parameter" })
        }
    }
}

if ($problems.Count -eq 0) {
    Write-Output "Script check passed: $($scripts.Count) scripts follow script."
    exit 0
}
Write-Output "Script check: $($problems.Count) problem(s)."
Write-Output ''
Write-Output '| Where | Problem |'
Write-Output '| --- | --- |'
foreach ($problem in $problems) {
    Write-Output "| ``$($problem.Where)`` | $($problem.What -replace '\|', '\|') |"
}
exit 1
