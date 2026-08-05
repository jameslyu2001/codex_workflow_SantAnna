[CmdletBinding()]
param([string]$InstallRoot)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$UserProfilePath = if ($InstallRoot) { [IO.Path]::GetFullPath($InstallRoot) } else { [Environment]::GetFolderPath("UserProfile") }
$CodexHomePath = if ($InstallRoot) { Join-Path $UserProfilePath ".codex" } elseif ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $UserProfilePath ".codex" }
$SkillsRoot = Join-Path $UserProfilePath ".agents\skills"
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Failures = [Collections.Generic.List[string]]::new()
$ReleasePath = Join-Path $PackageRoot "RELEASE.json"
$Release = if (Test-Path -LiteralPath $ReleasePath -PathType Leaf) {
    Get-Content -LiteralPath $ReleasePath -Raw -Encoding utf8 | ConvertFrom-Json
} else { $null }

function Require-Path {
    param([string]$Path, [string]$Label)
    if (Test-Path -LiteralPath $Path) {
        Write-Host "PASS  $Label"
    } else {
        Write-Host "FAIL  $Label"
        $Failures.Add("$Label ($Path)")
    }
}

Require-Path (Join-Path $CodexHomePath "AGENTS.md") "global AGENTS.md"
Require-Path (Join-Path $CodexHomePath "rules\academic-workflow.rules") "global Git safety rules"
Require-Path (Join-Path $CodexHomePath "agents\academic_methods_referee.toml") "methods referee agent"
Require-Path (Join-Path $SkillsRoot "academic-workflow-core\SKILL.md") "core workflow skill"
Require-Path (Join-Path $SkillsRoot "academic-workflow-init\SKILL.md") "project initializer skill"
Require-Path (Join-Path $SkillsRoot "academic-workflow-review-paper\SKILL.md") "paper review skill"
Require-Path (Join-Path $SkillsRoot "academic-workflow-style-academic-writing\SKILL.md") "academic writing style skill"
Require-Path (Join-Path $SkillsRoot "academic-workflow-style-referee\SKILL.md") "referee style skill"
Require-Path (Join-Path $CodexHomePath "academic-workflow-install.json") "installation manifest"
Require-Path (Join-Path $CodexHomePath "academic-workflow-state\personal-memory.md") "personal workflow memory"
Require-Path (Join-Path $SkillsRoot "academic-workflow-init\assets\project-scripts\compile-latex.ps1") "Windows LaTeX project script"
Require-Path (Join-Path $SkillsRoot "academic-workflow-init\assets\project-scripts\sync-to-docs.ps1") "Windows Quarto deployment script"

$GlobalAgentsPath = Join-Path $CodexHomePath "AGENTS.md"
if (Test-Path -LiteralPath $GlobalAgentsPath -PathType Leaf) {
    $GlobalAgentsText = Get-Content -LiteralPath $GlobalAgentsPath -Raw -Encoding utf8
    $BlockCount = ([regex]::Matches($GlobalAgentsText, '<!-- BEGIN academic-workflow -->')).Count
    if ($BlockCount -eq 1) { Write-Host "PASS  one global academic workflow block" }
    else { Write-Host "FAIL  global academic workflow block count ($BlockCount)"; $Failures.Add("global academic workflow block count") }
}

$GlobalOverridePath = Join-Path $CodexHomePath "AGENTS.override.md"
if (Test-Path -LiteralPath $GlobalOverridePath -PathType Leaf) {
    $GlobalOverrideText = Get-Content -LiteralPath $GlobalOverridePath -Raw -Encoding utf8
    if ($GlobalOverrideText -and $GlobalOverrideText.Trim()) {
        Write-Warning "$GlobalOverridePath is non-empty and takes precedence over the installed global AGENTS.md."
    }
}

$ManifestPath = Join-Path $CodexHomePath "academic-workflow-install.json"
$Manifest = $null
if (Test-Path -LiteralPath $ManifestPath -PathType Leaf) {
    $Manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding utf8 | ConvertFrom-Json
    $VersionPath = Join-Path $PackageRoot "VERSION"
    $ExpectedPackageVersion = if (Test-Path -LiteralPath $VersionPath -PathType Leaf) {
        (Get-Content -LiteralPath $VersionPath -Raw -Encoding utf8).Trim()
    } else { $null }
    $ManifestPackageVersion = if ($Manifest.PSObject.Properties.Name -contains "package_version") { $Manifest.package_version } else { $null }
    if ($ExpectedPackageVersion -and $ManifestPackageVersion -eq $ExpectedPackageVersion) {
        Write-Host "PASS  package version $ExpectedPackageVersion"
    } elseif ($ExpectedPackageVersion) {
        Write-Host "FAIL  package version"
        $Failures.Add("package version")
    }

    $ManifestSourceCommit = if ($Manifest.PSObject.Properties.Name -contains "source_commit") { $Manifest.source_commit } else { $null }
    $GitCommandForCommit = Get-Command git -ErrorAction SilentlyContinue
    if ($ManifestSourceCommit -and $GitCommandForCommit -and (Test-Path -LiteralPath (Join-Path $Manifest.source ".git"))) {
        $InstalledCommitOutput = & git -C $Manifest.source rev-parse HEAD 2>&1
        $InstalledCommit = if ($LASTEXITCODE -eq 0) { ($InstalledCommitOutput | Select-Object -First 1).ToString().Trim() } else { $null }
        if ($InstalledCommit -eq $ManifestSourceCommit) { Write-Host "PASS  upstream source commit $InstalledCommit" }
        else { Write-Host "FAIL  upstream source commit"; $Failures.Add("upstream source commit") }
    }
}

$SkillFiles = @(Get-ChildItem -LiteralPath $SkillsRoot -Directory -Filter "academic-workflow-*" -ErrorAction SilentlyContinue | ForEach-Object {
    Get-Item -LiteralPath (Join-Path $_.FullName "SKILL.md") -ErrorAction SilentlyContinue
})
Write-Host ("INFO  converted skills: " + $SkillFiles.Count)

$VendorSkillsRoot = Join-Path $CodexHomePath "vendor\academic-workflow\.claude\skills"
$ExpectedSkillCount = if ($Release -and $Release.PSObject.Properties.Name -contains 'expected_skills') {
    [int]$Release.expected_skills
} elseif (Test-Path -LiteralPath $VendorSkillsRoot) {
    @(Get-ChildItem -LiteralPath $VendorSkillsRoot -Directory).Count + 4
} else { 56 }
if ($SkillFiles.Count -eq $ExpectedSkillCount) { Write-Host "PASS  converted skill count" }
else { Write-Host "FAIL  converted skill count (expected $ExpectedSkillCount)"; $Failures.Add("converted skill count") }

foreach ($SkillFile in $SkillFiles) {
    $Text = Get-Content -LiteralPath $SkillFile.FullName -Raw -Encoding utf8
    if ($Text -notmatch '\A---\r?\nname:\s*[a-z0-9-]+\r?\ndescription:\s*.+?\r?\n---') {
        $Failures.Add("invalid skill frontmatter: $($SkillFile.FullName)")
    }
    $FolderName = Split-Path -Leaf (Split-Path -Parent $SkillFile.FullName)
    $FrontmatterName = if ($Text -match '(?m)^name:\s*([a-z0-9-]+)\s*$') { $Matches[1] } else { $null }
    if ($FrontmatterName -ne $FolderName) { $Failures.Add("skill folder/frontmatter mismatch: $($SkillFile.FullName)") }
    $Frontmatter = if ($Text -match '\A---\r?\n(.*?)\r?\n---') { $Matches[1] } else { '' }
    $UnexpectedKeys = @($Frontmatter -split '\r?\n' | Where-Object { $_ -match '^([A-Za-z0-9_-]+):' -and $Matches[1] -notin @('name', 'description') })
    if ($UnexpectedKeys.Count) { $Failures.Add("unexpected skill frontmatter key: $($SkillFile.FullName)") }
}
if (-not ($Failures | Where-Object { $_ -like "*skill frontmatter*" -or $_ -like "skill folder/frontmatter*" })) { Write-Host "PASS  skill frontmatter and folder names" }

$ForbiddenSkillPatterns = [ordered]@{
    invalid_argument_conversion = 'the arguments and context supplied by the user'
    claude_continue = '(?i)\bclaude\s+--continue\b'
    claude_headless = '(?i)\bclaude\s+-p\b'
    claude_mcp = '(?i)\bclaude\s+mcp\b'
    claude_project_variable = 'CLAUDE_PROJECT_DIR'
    claude_project_path = '(?i)(?<![A-Za-z0-9_-])\.claude[\\/]'
    claude_monitor_tool = '(?i)\bMonitor tool\b'
    claude_context_fork = 'context\s*[:=]\s*fork'
    claude_subagent_type = 'subagent_type\s*='
    claude_background_wording = '(?i)\bAnthropic''s\b|\b(via|using) Bash\b'
    undiscoverable_agent_name = '(?i)(`(?:beamer-translator|claim-verifier|domain-referee|domain-reviewer|editor|humanize-auditor|methods-referee|pedagogy-reviewer|promote-memory-council|proofreader|quarto-critic|quarto-fixer|r-package-reviewer|r-reviewer|sim-reviewer|slide-auditor|tikz-reviewer|verifier)`|(?:beamer-translator|claim-verifier|domain-referee|domain-reviewer|editor|humanize-auditor|methods-referee|pedagogy-reviewer|promote-memory-council|proofreader|quarto-critic|quarto-fixer|r-package-reviewer|r-reviewer|sim-reviewer|slide-auditor|tikz-reviewer|verifier)\s+(agent|subagent)|agent_type=(?:beamer-translator|claim-verifier|domain-referee|domain-reviewer|editor|humanize-auditor|methods-referee|pedagogy-reviewer|promote-memory-council|proofreader|quarto-critic|quarto-fixer|r-package-reviewer|r-reviewer|sim-reviewer|slide-auditor|tikz-reviewer|verifier))'
}
$SkillResidues = @()
foreach ($SkillFile in $SkillFiles) {
    $Text = Get-Content -LiteralPath $SkillFile.FullName -Raw -Encoding utf8
    foreach ($Entry in $ForbiddenSkillPatterns.GetEnumerator()) {
        if ($Text -match $Entry.Value) { $SkillResidues += "$($Entry.Key):$($SkillFile.FullName)" }
    }
}
if ($SkillResidues.Count -eq 0) { Write-Host "PASS  no active Claude/argument residues in skills" }
else { Write-Host "FAIL  active Claude/argument residues in skills"; $SkillResidues | ForEach-Object { $Failures.Add($_) } }

$AgentFiles = @(Get-ChildItem -LiteralPath (Join-Path $CodexHomePath "agents") -Filter "academic_*.toml" -File -ErrorAction SilentlyContinue)
Write-Host ("INFO  converted agents: " + $AgentFiles.Count)

$VendorAgentsRoot = Join-Path $CodexHomePath "vendor\academic-workflow\.claude\agents"
$ExpectedAgentCount = if ($Release -and $Release.PSObject.Properties.Name -contains 'expected_custom_agents') {
    [int]$Release.expected_custom_agents
} elseif (Test-Path -LiteralPath $VendorAgentsRoot) {
    @(Get-ChildItem -LiteralPath $VendorAgentsRoot -Filter "*.md" -File).Count
} else { 18 }
if ($AgentFiles.Count -eq $ExpectedAgentCount) { Write-Host "PASS  converted agent count" }
else { Write-Host "FAIL  converted agent count (expected $ExpectedAgentCount)"; $Failures.Add("converted agent count") }

foreach ($AgentFile in $AgentFiles) {
    $Text = Get-Content -LiteralPath $AgentFile.FullName -Raw -Encoding utf8
    foreach ($RequiredKey in @("name", "description", "developer_instructions")) {
        if ($Text -notmatch "(?m)^$RequiredKey\s*=") { $Failures.Add("agent missing $RequiredKey`: $($AgentFile.FullName)") }
    }
    if ($Text -notmatch '(?m)^sandbox_mode\s*=\s*"(read-only|workspace-write)"\s*$') {
        $Failures.Add("agent invalid sandbox_mode: $($AgentFile.FullName)")
    }
    foreach ($Pattern in @(
        'the arguments and context supplied by the user',
        '(?i)\bclaude\s+(--continue|-p|mcp)\b',
        'CLAUDE_PROJECT_DIR',
        '(?i)(?<![A-Za-z0-9_-])\.claude[\\/]',
        'Grep / Read / Glob',
        '(?i)\bMonitor tool\b',
        'a (high-judgment|balanced|fast) Codex model\s+\d'
    )) {
        if ($Text -match $Pattern) { $Failures.Add("agent Claude residue: $($AgentFile.FullName)") }
    }
}
if (-not ($Failures | Where-Object { $_ -like "agent missing*" -or $_ -like "agent invalid*" -or $_ -like "agent Claude residue*" })) { Write-Host "PASS  agent fields, sandboxes, and Codex conversion" }

$HooksConfigPath = Join-Path $CodexHomePath "hooks.json"
$HooksRoot = Join-Path $CodexHomePath "hooks\academic-workflow"
$ManifestHooksConfig = if ($Manifest -and $Manifest.PSObject.Properties.Name -contains 'hooks_config') { $Manifest.hooks_config } else { $null }
if ($ManifestHooksConfig) {
    Require-Path $HooksConfigPath "Codex hook configuration"
    $HookScripts = @(Get-ChildItem -LiteralPath $HooksRoot -File -Filter '*.py' -ErrorAction SilentlyContinue)
    $ExpectedHookScripts = if ($Release -and $Release.PSObject.Properties.Name -contains 'expected_hook_scripts') { [int]$Release.expected_hook_scripts } else { 6 }
    if ($HookScripts.Count -eq $ExpectedHookScripts) { Write-Host "PASS  Codex hook scripts ($ExpectedHookScripts)" }
    else { Write-Host "FAIL  Codex hook script count"; $Failures.Add("Codex hook script count") }

    if (Test-Path -LiteralPath $HooksConfigPath -PathType Leaf) {
        try {
            $HooksConfig = Get-Content -LiteralPath $HooksConfigPath -Raw -Encoding utf8 | ConvertFrom-Json
            $AcademicHookGroups = 0
            foreach ($EventProperty in $HooksConfig.hooks.PSObject.Properties) {
                foreach ($Group in @($EventProperty.Value)) {
                    if (-not $Group.PSObject.Properties['hooks']) { continue }
                    $FoundAcademic = $false
                    foreach ($Handler in @($Group.PSObject.Properties['hooks'].Value)) {
                        foreach ($Name in @('command', 'commandWindows', 'command_windows')) {
                            $Property = $Handler.PSObject.Properties[$Name]
                            if ($Property -and $Property.Value -match '[\\/]academic-workflow[\\/]') {
                                $FoundAcademic = $true
                                break
                            }
                        }
                        if ($FoundAcademic) { break }
                    }
                    if ($FoundAcademic) { $AcademicHookGroups++ }
                }
            }
            $ExpectedHookGroups = if ($Release -and $Release.PSObject.Properties.Name -contains 'expected_hook_groups') { [int]$Release.expected_hook_groups } else { 5 }
            if ($AcademicHookGroups -eq $ExpectedHookGroups) { Write-Host "PASS  Codex academic hook groups ($ExpectedHookGroups)" }
            else { Write-Host "FAIL  Codex academic hook groups ($AcademicHookGroups/$ExpectedHookGroups)"; $Failures.Add("Codex academic hook groups") }
        } catch {
            Write-Host "FAIL  Codex hook JSON parse"
            $Failures.Add("Codex hook JSON parse")
        }
    }

    $PythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if ($PythonCommand) {
        foreach ($HookScript in $HookScripts) {
            & $PythonCommand.Source -c "import ast,pathlib,sys; ast.parse(pathlib.Path(sys.argv[1]).read_text(encoding='utf-8'))" $HookScript.FullName
            if ($LASTEXITCODE -ne 0) { $Failures.Add("hook Python parse: $($HookScript.FullName)") }
        }
        if (-not ($Failures | Where-Object { $_ -like 'hook Python parse:*' })) { Write-Host "PASS  hook Python syntax" }
    } else {
        Write-Host "FAIL  Python is required by installed hooks"
        $Failures.Add("Python required by installed hooks")
    }
}

$ManifestCliUi = if ($Manifest -and $Manifest.PSObject.Properties.Name -contains 'cli_ui_defaults_installed') { [bool]$Manifest.cli_ui_defaults_installed } else { $false }
if ($ManifestCliUi) {
    $ConfigPath = Join-Path $CodexHomePath 'config.toml'
    if ((Test-Path -LiteralPath $ConfigPath -PathType Leaf) -and (Select-String -LiteralPath $ConfigPath -Pattern '^\s*status_line\s*=' -Quiet)) {
        Write-Host "PASS  Codex native status line configuration"
    } else {
        Write-Host "FAIL  Codex native status line configuration"
        $Failures.Add("Codex native status line configuration")
    }
}

$RulesPath = Join-Path $CodexHomePath "rules\academic-workflow.rules"
$CodexCommand = Get-Command codex -ErrorAction SilentlyContinue
if ($CodexCommand) {
    $PolicyCases = @(
        [pscustomobject]@{ Arguments = @('git', 'reset', '--hard', 'HEAD~1'); Expected = 'forbidden' },
        [pscustomobject]@{ Arguments = @('git', 'clean', '-fdx'); Expected = 'forbidden' },
        [pscustomobject]@{ Arguments = @('git', 'checkout', '--', '.'); Expected = 'forbidden' },
        [pscustomobject]@{ Arguments = @('git', 'add', '.'); Expected = 'prompt' },
        [pscustomobject]@{ Arguments = @('git', 'push', '--force', 'origin', 'main'); Expected = 'prompt' }
    )
    $PolicyFailed = $false
    foreach ($Case in $PolicyCases) {
        $PolicyArguments = @('execpolicy', 'check', '--pretty', '--rules', $RulesPath, '--') + @($Case.Arguments)
        $PolicyOutput = & codex @PolicyArguments 2>&1
        $Decision = if ($LASTEXITCODE -eq 0) {
            (($PolicyOutput -join [Environment]::NewLine) | ConvertFrom-Json).decision
        } else { $null }
        if ($Decision -ne $Case.Expected) { $PolicyFailed = $true }
    }
    if (-not $PolicyFailed) { Write-Host "PASS  executable Git safety policy" }
    else {
        Write-Host "FAIL  executable Git safety policy"
        $Failures.Add("executable Git safety policy")
    }
} else {
    Write-Host "FAIL  codex command not available"
    $Failures.Add("codex command not available")
}

$InitScriptPath = Join-Path $SkillsRoot "academic-workflow-init\scripts\init-project.ps1"
$Tokens = $null
$ParseErrors = $null
[Management.Automation.Language.Parser]::ParseFile($InitScriptPath, [ref]$Tokens, [ref]$ParseErrors) | Out-Null
if ($ParseErrors.Count -eq 0) { Write-Host "PASS  project initializer syntax" }
else { Write-Host "FAIL  project initializer syntax"; $Failures.Add("project initializer syntax") }

foreach ($ProjectScriptName in @('compile-latex.ps1', 'sync-to-docs.ps1')) {
    $ProjectScriptPath = Join-Path $SkillsRoot "academic-workflow-init\assets\project-scripts\$ProjectScriptName"
    $ScriptTokens = $null
    $ScriptErrors = $null
    [Management.Automation.Language.Parser]::ParseFile($ProjectScriptPath, [ref]$ScriptTokens, [ref]$ScriptErrors) | Out-Null
    if ($ScriptErrors.Count -ne 0) { $Failures.Add("project script syntax: $ProjectScriptName") }
}
if (-not ($Failures | Where-Object { $_ -like 'project script syntax:*' })) { Write-Host "PASS  Windows project script syntax" }

foreach ($CommandName in @("git", "codex", "python", "Rscript", "xelatex", "quarto")) {
    $Available = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($Available) { Write-Host "INFO  tool available: $CommandName" }
    elseif ($CommandName -eq "git" -or $CommandName -eq "codex" -or ($CommandName -eq "python" -and $ManifestHooksConfig)) {
        Write-Host "FAIL  required tool missing: $CommandName"
        if (-not $Failures.Contains("$CommandName command not available")) { $Failures.Add("$CommandName command not available") }
    } else { Write-Host "INFO  optional tool missing: $CommandName" }
}

if ($Failures.Count -gt 0) {
    Write-Host ""
    Write-Host "Verification failed:"
    $Failures | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host ""
Write-Host "Static installation checks passed. Restart Codex to refresh skills and custom agents."
