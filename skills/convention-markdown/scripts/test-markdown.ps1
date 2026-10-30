#Requires -Version 7
<# Runs regression cases for comment handling and prose-wrap enforcement. #>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..')
$fixtureDirectory = Join-Path $repositoryRoot '.artifacts/markdown-tests'
New-Item -ItemType Directory -Path $fixtureDirectory -Force | Out-Null
$checker = Join-Path $PSScriptRoot 'check-markdown.ps1'
$cases = @(
    @{ Name = 'multiline-comment'; Body = "<!--`nhidden text`n-->"; Exit = 0 }
    @{ Name = 'comment-syntax'; Body = (@('<!--', '``` ', '# Hidden heading', '_hidden_', '-->') -join "`n"); Exit = 0 }
    @{ Name = 'inline-comment'; Body = 'Visible <!-- hidden --> prose.'; Exit = 0 }
    @{ Name = 'trailing-comment'; Body = 'Visible prose. <!-- hidden -->'; Exit = 0 }
    @{ Name = 'multiple-comments'; Body = '<!-- first --> <!-- second -->'; Exit = 0 }
    @{ Name = 'comment-in-inline-code'; Body = ('Use `<!--` to start a comment.' + "`nContinued prose."); Exit = 1 }
    @{ Name = 'escaped-comment'; Body = ('Use \<!-- as literal text.' + "`nContinued prose."); Exit = 1 }
    @{ Name = 'wrapped-prose'; Body = "Visible prose`ncontinued here."; Exit = 1 }
    @{ Name = 'wrap-before-comment'; Body = "Visible prose`ncontinued here.`n<!-- hidden -->"; Exit = 1 }
    @{ Name = 'wrap-after-comment'; Body = "<!-- hidden -->`nVisible prose`ncontinued here."; Exit = 1 }
    @{ Name = 'visible-suffix'; Body = "<!-- hidden`n--> Visible prose`ncontinued here."; Exit = 1 }
    @{ Name = 'comment-in-code'; Body = (@('```html', '<!--', '```', '', 'Visible prose', 'continued here.') -join "`n"); Exit = 1 }
)

$failures = @()
foreach ($case in $cases) {
    $fixture = Join-Path $fixtureDirectory ($case.Name + '.txt')
    [IO.File]::WriteAllText($fixture, "# Example`n`n$($case.Body)`n")
    $output = & pwsh -NoProfile -File $checker -Path $fixture 2>&1
    if ($LASTEXITCODE -ne $case.Exit -or ($case.Exit -eq 1 -and "$output" -notmatch 'line.wrap')) {
        $failures += $case.Name
        Write-Output "FAIL $($case.Name): $output"
    }
}
if ($failures.Count) { throw "$($failures.Count) of $($cases.Count) Markdown regression cases failed." }
Write-Output "All $($cases.Count) Markdown regression cases passed."
