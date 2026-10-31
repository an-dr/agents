#Requires -Version 7
<# Runtime coverage for the tool targets shared by install-agents and verify-agents. #>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '..\Install.Common.psm1') -Force

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

$all = @(Get-AgentsToolTarget -Only @('claude', 'codex', 'copilot', 'deepseek', 'gemini', 'opencode'))
Assert-True ($all.Count -eq 6) "expected six tool targets, got $($all.Count)"
Assert-True (@($all.Id | Sort-Object -Unique).Count -eq 6) 'tool ids must be unique'

$profileDir = [Environment]::GetFolderPath('UserProfile')
foreach ($tool in $all) {
    Assert-True ([bool]$tool.Id -and [bool]$tool.Name) "a target is missing its id or name: $($tool.Id)"
    Assert-True ($tool.Instructions.StartsWith($tool.Home, [StringComparison]::OrdinalIgnoreCase)) "$($tool.Id): instructions must live under its home"
    if ($tool.SkillsDir) {
        Assert-True ($tool.SkillsDir.StartsWith($tool.Home, [StringComparison]::OrdinalIgnoreCase)) "$($tool.Id): skills dir must live under its home"
    }
}

$deepseek = @($all | Where-Object Id -eq 'deepseek')
Assert-True ($deepseek.Count -eq 1) 'the deepseek target is missing'
$tool = $deepseek[0]
Assert-True ($tool.Name -eq 'DeepSeek Harness') "unexpected tool name: $($tool.Name)"
Assert-True ($tool.Home -eq (Join-Path $profileDir '.dsh')) "unexpected home: $($tool.Home)"
Assert-True ($tool.Instructions -eq (Join-Path $profileDir '.dsh\AGENTS.md')) "unexpected instruction file: $($tool.Instructions)"
Assert-True ($tool.SkillsDir -eq (Join-Path $profileDir '.dsh\skills')) "unexpected skills directory: $($tool.SkillsDir)"
Assert-True (-not $tool.SupportsImport) 'DeepSeek Harness does not expand @ imports in its instruction files'

$root = Resolve-AgentsRoot
$policy = ($root -replace '\\', '/') + '/AGENTS.md'
$block = Build-AgentsBlock -AgentsRoot $root -SupportsImport $tool.SupportsImport
Assert-True ($block -like "*$policy*") 'the managed block must name the policy path'
Assert-True ($block -notlike "*@$policy*") 'a tool without import support must not receive an @ reference'

$rejected = $false
try { Get-AgentsToolTarget -Only 'unknown-tool' | Out-Null } catch { $rejected = $true }
Assert-True $rejected 'an unknown tool id must be rejected'

Write-Output "Tool targets passed: $($all.Count) targets, deepseek at $($tool.SkillsDir)."

