#Requires -Version 7
<#
    Checks every SKILL.md against the Agent Skills format and agent-skill:
    only the standard frontmatter keys, a valid name and description, string-valued
    metadata, a space-separated allowed-tools, the an-dr.type and an-dr.dependencies
    extensions, a description that ends in a trigger sentence, one title that matches
    the skill's type, the section order for that type, and that every reference file
    is linked and every linked reference exists. Warns on a SKILL.md or reference file
    over the token budget, a description over the length budget, and a command block
    in a concept or convention. Prints Markdown
    tables of warnings and problems, and exits 1 when there are problems.
#>
[CmdletBinding()]
param([string]$Root = (Join-Path $PSScriptRoot '../../../..'))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = (Resolve-Path -LiteralPath $Root).ProviderPath
$skillsDir = Join-Path $Root 'skills'
# Approximate tokens are characters / 4, as the Size and references section defines.
$maxTokens = 1500
$maxDescription = 300
$standardKeys = @('name', 'description', 'license', 'compatibility', 'metadata', 'allowed-tools')
$problems = [System.Collections.Generic.List[object]]::new()
function Add-Problem([string]$Where, [string]$What) {
    $problems.Add([pscustomobject]@{ Where = $Where; What = $What })
}
$warnings = [System.Collections.Generic.List[object]]::new()
function Add-Warning([string]$Where, [string]$What) {
    $warnings.Add([pscustomobject]@{ Where = $Where; What = $What })
}
function Get-Tokens([string]$Text) { [int][Math]::Round($Text.Length / 4) }

$checked = 0
foreach ($file in Get-ChildItem -Path (Join-Path $skillsDir '*/*/SKILL.md') | Sort-Object FullName) {
    $name = $file.Directory.Name
    $checked++
    $where = 'skills/' + $file.Directory.Parent.Name + "/$name/SKILL.md"
    $lines = [IO.File]::ReadAllLines($file.FullName)

    # Frontmatter: top-level keys, one level of metadata, and where the body starts.
    $keys = [ordered]@{}
    $metadata = [ordered]@{}
    $bodyStart = 0
    $inMetadata = $false
    if ($lines.Count -gt 0 -and $lines[0] -eq '---') {
        for ($i = 1; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -eq '---') { $bodyStart = $i + 1; break }
            if ($line -match '^(?<k>[^\s:][^:]*):\s*(?<v>.*)$') {
                $keys[$Matches['k']] = $Matches['v']
                $inMetadata = $Matches['k'] -ceq 'metadata'
            }
            elseif ($inMetadata -and $line -match '^  (?<k>[^\s:][^:]*):\s*(?<v>.+)$') { $metadata[$Matches['k']] = $Matches['v'] }
            elseif ($inMetadata -and $line.Trim()) { Add-Problem $where "metadata line '$($line.Trim())' is not a flat key: value pair" }
        }
    }
    else { Add-Problem $where 'has no frontmatter' }

    foreach ($key in $keys.Keys) {
        if ($key -cnotin $standardKeys) { Add-Problem $where "frontmatter key '$key' is not part of the Agent Skills format; put extensions under metadata" }
    }
    if ($keys['name'] -cne $name) { Add-Problem $where "frontmatter name '$($keys['name'])' does not match its folder" }
    if ($name -cnotmatch '^[a-z0-9]+(-[a-z0-9]+)*$' -or $name.Length -gt 64) { Add-Problem $where 'name must be 1-64 lowercase letters, digits, and single hyphens' }
    if ($keys.Contains('allowed-tools') -and $keys['allowed-tools'] -match '[,\[\]]') {
        Add-Problem $where 'allowed-tools must be a space-separated string, without commas or brackets'
    }
    if (-not $keys.Contains('license') -or -not $keys['license']) { Add-Problem $where 'has no license' }
    if ($metadata.Contains('version') -and $metadata['version'] -cnotmatch '^"?\d+\.\d+\.\d+"?$') { Add-Problem $where 'metadata version must be a semantic version such as "1.0.0"' }
    foreach ($required in @('author', 'version', 'an-dr.type', 'an-dr.dependencies')) {
        if (-not $metadata.Contains($required)) { Add-Problem $where "metadata has no $required" }
    }
    foreach ($key in $metadata.Keys) {
        if ($metadata[$key] -match '^[\[{|>]') { Add-Problem $where "metadata $key must be a plain string, not a list or map" }
    }

    $description = if ($keys.Contains('description')) { $keys['description'] } else { $null }
    if (-not $description) { Add-Problem $where 'has no one-line description' }
    else {
        if ($description -match ': | #') { Add-Problem $where "description contains ': ' or ' #', which is invalid in an unquoted YAML value; use a dash or rephrase" }
        if ($description.Length -gt 1024) { Add-Problem $where "description is $($description.Length) characters; the limit is 1024" }
        elseif ($description.Length -gt $maxDescription) { Add-Warning $where "description is $($description.Length) characters; the budget is $maxDescription" }
        if ($description -cnotmatch '^[A-Z]') { Add-Problem $where 'description does not start with a capital letter' }
        if ($description -cnotmatch '(^|[.;] )Use [a-z]') { Add-Problem $where "description has no trigger sentence beginning 'Use '" }
    }
    $text = $lines -join "`n"
    $kindForCommands = if ($metadata.Contains('an-dr.type')) { $metadata['an-dr.type'] } else { 'action' }
    if ($kindForCommands -in @('concept', 'convention') -and $text -match '(?m)^```powershell') {
        Add-Warning $where "a $kindForCommands contains a command to run; it only describes, and running belongs to an action"
    }
    $tokens = Get-Tokens $text
    if ($tokens -gt $maxTokens) { Add-Warning $where "is about $tokens tokens; the budget is $maxTokens, so move branch material into references/" }

    # References: every file under references/ is linked from SKILL.md, and every such link resolves.
    $skillWhere = 'skills/' + $file.Directory.Parent.Name + "/$name"
    # A link shown as an example inside inline code is not a link.
    $prose = $text -replace '`[^`\n]*`', ''
    foreach ($link in [regex]::Matches($prose, '\]\((?<p>references/[^)#\s]+)')) {
        $target = Join-Path $file.DirectoryName $link.Groups['p'].Value
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { Add-Problem $where "links $($link.Groups['p'].Value), which does not exist" }
    }
    $referenceDir = Join-Path $file.DirectoryName 'references'
    if (Test-Path -LiteralPath $referenceDir -PathType Container) {
        foreach ($reference in Get-ChildItem -LiteralPath $referenceDir -Filter '*.md' -File -Recurse) {
            $relative = 'references/' + ($reference.FullName.Substring($referenceDir.Length + 1) -replace '\\', '/')
            if (-not $prose.Contains("]($relative")) { Add-Problem "$skillWhere/$relative" 'is not linked from SKILL.md, so no agent reads it' }
            $referenceTokens = Get-Tokens ([IO.File]::ReadAllText($reference.FullName))
            if ($referenceTokens -gt $maxTokens) { Add-Warning "$skillWhere/$relative" "is about $referenceTokens tokens; the budget is $maxTokens" }
        }
    }

    $kind = if ($metadata.Contains('an-dr.type')) { $metadata['an-dr.type'] } else { 'action' }

    # Headings outside code fences.
    $titles = [System.Collections.Generic.List[string]]::new()
    $sections = [System.Collections.Generic.List[string]]::new()
    $inFence = $false
    for ($i = $bodyStart; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^```') { $inFence = -not $inFence; continue }
        if ($inFence) { continue }
        if ($lines[$i] -match '^# (?<t>.+)$') { $titles.Add($Matches['t']) }
        elseif ($lines[$i] -match '^## (?<t>.+)$') { $sections.Add($Matches['t']) }
    }

    if ($titles.Count -ne 1) { Add-Problem $where "has $($titles.Count) top-level titles; it needs exactly one" }
    elseif ($kind -eq 'concept' -and $titles[0] -cnotmatch '^Concept: ') { Add-Problem $where "title '$($titles[0])' must start with 'Concept: '" }
    elseif ($kind -eq 'convention' -and $titles[0] -cnotmatch '^Convention: ') { Add-Problem $where "title '$($titles[0])' must start with 'Convention: '" }
    elseif ($kind -eq 'action' -and $titles[0] -cmatch '^(Concept|Convention): ') { Add-Problem $where "title '$($titles[0])' uses a concept or convention prefix on an action" }

    $last = if ($sections.Count -gt 0) { $sections[$sections.Count - 1] } else { $null }
    switch ($kind) {
        'action' {
            if ($sections -contains 'Rules' -and $last -cne 'Rules') { Add-Problem $where "'## Rules' must be the last section, not '## $last'" }
            if ($sections -contains 'Output' -and $sections -contains 'Rules' -and $sections.IndexOf('Output') -gt $sections.IndexOf('Rules')) {
                Add-Problem $where "'## Output' must come before '## Rules'"
            }
        }
        'concept' {
            if ($sections -notcontains 'Violations') { Add-Problem $where "has no '## Violations' section" }
        }
        'convention' {
            if ($sections -contains 'Examples' -and $last -cne 'Examples') { Add-Problem $where "'## Examples' must be the last section, not '## $last'" }
            if ($sections -contains 'Check' -and $sections -contains 'Examples' -and $sections.IndexOf('Check') -gt $sections.IndexOf('Examples')) {
                Add-Problem $where "'## Check' must come before '## Examples'"
            }
        }
    }
}

if ($warnings.Count -gt 0) {
    Write-Output "Size warnings: $($warnings.Count). They do not fail the check."
    Write-Output ''
    Write-Output '| Where | Warning |'
    Write-Output '| --- | --- |'
    foreach ($warning in $warnings) { Write-Output "| ``$($warning.Where)`` | $($warning.What) |" }
    Write-Output ''
}
if ($problems.Count -eq 0) {
    Write-Output "Skill check passed: $checked skills follow the Agent Skills format and agent-skill."
    exit 0
}
Write-Output "Skill check: $($problems.Count) problem(s)."
Write-Output ''
Write-Output '| Where | Problem |'
Write-Output '| --- | --- |'
foreach ($problem in $problems) {
    Write-Output "| ``$($problem.Where)`` | $($problem.What -replace '\|', '\|') |"
}
exit 1
