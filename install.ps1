[CmdletBinding()]
param(
    [string]$SourcePath,
    [string]$InstallRoot,
    [string]$RepositoryUrl = "https://github.com/pedrohcgs/claude-code-my-workflow.git",
    [string]$RepositoryRef = "be53c12f235996dff41fb7f21580506fd2dd8d50",
    [switch]$BypassGitHubProxy,
    [switch]$SkipGlobalAgentsBlock,
    [switch]$SkipHooks,
    [switch]$SkipCliUiDefaults
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$UserProfilePath = if ($InstallRoot) { [IO.Path]::GetFullPath($InstallRoot) } else { [Environment]::GetFolderPath("UserProfile") }
$CodexHomePath = if ($InstallRoot) { Join-Path $UserProfilePath ".codex" } elseif ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $UserProfilePath ".codex" }
$UserSkillsPath = Join-Path $UserProfilePath ".agents\skills"
$VendorPath = Join-Path $CodexHomePath "vendor\academic-workflow"
$GlobalAgentsPath = Join-Path $CodexHomePath "AGENTS.md"
$GlobalAgentsOverridePath = Join-Path $CodexHomePath "AGENTS.override.md"
$GlobalCustomAgentsPath = Join-Path $CodexHomePath "agents"
$GlobalRulesPath = Join-Path $CodexHomePath "rules"
$GlobalHooksPath = Join-Path $CodexHomePath "hooks\academic-workflow"
$GlobalHooksConfigPath = Join-Path $CodexHomePath "hooks.json"
$GlobalConfigPath = Join-Path $CodexHomePath "config.toml"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupPath = Join-Path $CodexHomePath "backups\academic-workflow\$Timestamp"
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Ensure-Directory {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }
}

function Write-Utf8Text {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )

    $Utf8NoBom = New-Object Text.UTF8Encoding($false)
    for ($Attempt = 1; $Attempt -le 10; $Attempt++) {
        try {
            [IO.File]::WriteAllText($Path, $Value, $Utf8NoBom)
            return
        } catch [IO.IOException] {
            if ($Attempt -eq 10) { throw }
            Start-Sleep -Milliseconds 300
        }
    }
}

function Invoke-GitChecked {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$FailureMessage
    )

    $EffectiveArguments = @()
    if ($BypassGitHubProxy) {
        $EffectiveArguments += @("-c", "http.https://github.com.proxy=", "-c", "https.https://github.com.proxy=")
    }
    $EffectiveArguments += $Arguments
    $GitOutput = & git @EffectiveArguments 2>&1
    $GitExitCode = $LASTEXITCODE
    $GitOutput | ForEach-Object { Write-Host $_ }
    if ($GitExitCode -ne 0) { throw $FailureMessage }
}

function Backup-File {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    Ensure-Directory $BackupPath
    $Hasher = [Security.Cryptography.SHA256]::Create()
    try {
        $PathBytes = [Text.Encoding]::UTF8.GetBytes([IO.Path]::GetFullPath($Path).ToLowerInvariant())
        $PathHash = ([BitConverter]::ToString($Hasher.ComputeHash($PathBytes)) -replace '-', '').Substring(0, 12).ToLowerInvariant()
    } finally {
        $Hasher.Dispose()
    }
    $LeafName = ([IO.Path]::GetFileName($Path) -replace '[^A-Za-z0-9._-]', '_')
    $SafeName = "$PathHash-$LeafName"
    Copy-Item -LiteralPath $Path -Destination (Join-Path $BackupPath $SafeName) -Force
}

function Get-FrontmatterValue {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Key
    )
    $Match = [regex]::Match($Text, "(?m)^" + [regex]::Escape($Key) + ":\s*(.+)$")
    if (-not $Match.Success) { return $null }
    return $Match.Groups[1].Value.Trim().Trim('"').Trim("'")
}

function Remove-Frontmatter {
    param([Parameter(Mandatory)][string]$Text)
    return [regex]::Replace($Text, "\A---\s*\r?\n.*?\r?\n---\s*\r?\n", "", [Text.RegularExpressions.RegexOptions]::Singleline)
}

function Convert-ClaudeText {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$SkillNames
    )

    $Converted = $Text
    $Converted = $Converted.Replace('$ARGUMENTS', "<user-input>")
    $Converted = $Converted.Replace('$CLAUDE_PROJECT_DIR', "the current Git repository root")
    $Converted = $Converted.Replace(".claude/rules/", "../academic-workflow-core/references/rules/")
    $Converted = $Converted.Replace("../../rules/", "../academic-workflow-core/references/rules/")
    $Converted = $Converted.Replace(".claude/references/", "../academic-workflow-core/references/upstream/")
    $Converted = $Converted.Replace("../../references/", "../academic-workflow-core/references/upstream/")
    $Converted = $Converted.Replace("../../../templates/", "../academic-workflow-core/assets/templates/")
    $Converted = $Converted.Replace("Task tool", "Codex subagent tools")
    $Converted = $Converted.Replace("via Task", "with a Codex subagent")
    $Converted = $Converted.Replace('`Task`', "Codex subagent delegation")
    $Converted = $Converted.Replace("Grep / Read / Glob", "search and read the cited files")
    $Converted = $Converted.Replace("Glob/Read", "file search and reading")
    $Converted = $Converted.Replace('`Glob`/`Read`', "file search and reading")
    $Converted = $Converted.Replace("AskUserQuestion", "ask the user")
    $Converted = $Converted.Replace("Monitor tool", "Codex background-process monitoring or wait tools")
    $Converted = $Converted.Replace("the Monitor tool", "Codex background-process monitoring or wait tools")
    $Converted = $Converted.Replace('`run_in_background: true`', "background execution enabled")
    $Converted = $Converted.Replace("run_in_background: true", "background execution enabled")
    $Converted = $Converted.Replace('the `bash_id`', "the returned process identifier")
    $Converted = $Converted.Replace("Anthropic's **Codex background-process monitoring or wait tools**", "Codex background-process monitoring or wait tools")
    $Converted = $Converted.Replace("via Bash", "using the available background-process mechanism")
    $Converted = $Converted.Replace("using Bash", "using the available background-process mechanism")
    $Converted = $Converted.Replace("context: fork", "fork_turns: none")
    $Converted = $Converted.Replace("context=fork", 'fork_turns="none"')
    $Converted = $Converted.Replace("subagent_type=", "agent_type=")
    $Converted = $Converted.Replace("WebSearch", "web search")
    $Converted = $Converted.Replace("WebFetch", "page retrieval")
    $Converted = [regex]::Replace($Converted, '\bOpus(?:\s+\d+(?:\.\d+)*)?', 'the configured high-judgment Codex model')
    $Converted = [regex]::Replace($Converted, '\bSonnet(?:\s+\d+(?:\.\d+)*)?', 'the configured balanced Codex model')
    $Converted = [regex]::Replace($Converted, '\bHaiku(?:\s+\d+(?:\.\d+)*)?', 'the configured fast Codex model')
    $Converted = $Converted.Replace('`Glob`', 'file search')
    $Converted = $Converted.Replace('`Grep`', 'text search')
    $Converted = $Converted.Replace('`Read`', 'file reading')
    $Converted = $Converted.Replace('`Write`', 'file writing')
    $Converted = $Converted.Replace('`Edit`', 'file editing')
    $Converted = $Converted.Replace('`MultiEdit`', 'file editing')
    $Converted = $Converted.Replace('`Bash`', 'the shell')
    $Converted = $Converted.Replace("[Claude Code](https://claude.com/claude-code)", "Codex")
    $Converted = $Converted.Replace("Claude Code", "Codex")
    $Converted = [regex]::Replace($Converted, '(?<![A-Za-z0-9_-])claude\s+--continue\b', 'codex resume --last', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $Converted = [regex]::Replace($Converted, '(?<![A-Za-z0-9_-])claude\s+-p\b', 'codex exec', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $Converted = [regex]::Replace($Converted, '(?<![A-Za-z0-9_-])claude\s+mcp\b', 'codex mcp', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $Converted = [regex]::Replace($Converted, '\bClaude\b', 'Codex')
    $Converted = $Converted.Replace("CLAUDE.md", "AGENTS.md")
    $Converted = $Converted.Replace(".claude/state/personal-memory.md", "~/.codex/academic-workflow-state/personal-memory.md")
    $Converted = $Converted.Replace(".claude/state/", "~/.codex/academic-workflow-state/")
    $Converted = $Converted.Replace("CLAUDE_STRICT_PATHS", "CODEX_ACADEMIC_STRICT_PATHS")
    $Converted = $Converted.Replace("CLAUDE_COMPILE_GATE", "CODEX_ACADEMIC_COMPILE_GATE")
    $Converted = $Converted.Replace("CLAUDE_PRECOMPACT_BLOCK_ON_DRAFT", "CODEX_ACADEMIC_PRECOMPACT_BLOCK_ON_DRAFT")
    $Converted = [regex]::Replace(
        $Converted,
        '(?m)^- `\.claude/hooks/pre-compact\.py`.*$',
        '- The Codex-native PreCompact hook records plan and session state; use `$academic-workflow-compress-session` for an explicit durable handoff.'
    )
    $Converted = [regex]::Replace(
        $Converted,
        ' or sets `verifyClaims\.allowHighWarn: true` in `\.claude/settings\.json`',
        ''
    )

    $Converted = [regex]::Replace(
        $Converted,
        '\[`?\.claude/agents/([a-z0-9-]+)\.md`?\]\((?:\.\./)+agents/\1\.md\)',
        { param($Match) '`academic_' + $Match.Groups[1].Value.Replace("-", "_") + '` custom agent' }
    )
    $Converted = [regex]::Replace(
        $Converted,
        '(?:\.claude/agents/|(?:\.\./)+agents/)([a-z0-9-]+)\.md',
        { param($Match) '`academic_' + $Match.Groups[1].Value.Replace("-", "_") + '` custom agent' }
    )
    $Converted = [regex]::Replace(
        $Converted,
        '\[[^\]]+\]\(`?(academic_[a-z0-9_]+)`? custom agent\)',
        { param($Match) '`' + $Match.Groups[1].Value + '` custom agent' }
    )
    $Converted = [regex]::Replace(
        $Converted,
        '\.claude/skills/([a-z0-9-]+)(?:/SKILL\.md)?',
        { param($Match) '$academic-workflow-' + $Match.Groups[1].Value }
    )
    $Converted = $Converted.Replace(".claude/skills/", "~/.agents/skills/")
    $Converted = $Converted.Replace(".claude/agents/", "~/.codex/agents/")
    $Converted = $Converted.Replace(".claude/hooks/", "~/.codex/hooks/academic-workflow/")
    $Converted = $Converted.Replace(".claude/output-styles/academic-writing.md", '$academic-workflow-style-academic-writing')
    $Converted = $Converted.Replace(".claude/output-styles/referee.md", '$academic-workflow-style-referee')
    $Converted = $Converted.Replace(".claude/settings.local.json", ".codex/config.toml")
    $Converted = $Converted.Replace(".claude/settings.json", "~/.codex/config.toml")

    foreach ($AgentBaseName in @(
        'beamer-translator', 'claim-verifier', 'domain-referee', 'domain-reviewer', 'editor',
        'humanize-auditor', 'methods-referee', 'pedagogy-reviewer', 'promote-memory-council',
        'proofreader', 'quarto-critic', 'quarto-fixer', 'r-package-reviewer', 'r-reviewer',
        'sim-reviewer', 'slide-auditor', 'tikz-reviewer', 'verifier'
    )) {
        $CodexAgentName = 'academic_' + $AgentBaseName.Replace('-', '_')
        $Converted = $Converted.Replace('`' + $AgentBaseName + '`', '`' + $CodexAgentName + '`')
        $Converted = $Converted.Replace($AgentBaseName + '.md', $CodexAgentName + '.toml')
        $Converted = $Converted.Replace('agent_type=' + $AgentBaseName, 'agent_type=' + $CodexAgentName)
        $Converted = $Converted.Replace($AgentBaseName + ' agent', '`' + $CodexAgentName + '` custom agent')
        $Converted = $Converted.Replace($AgentBaseName + ' subagent', '`' + $CodexAgentName + '` custom agent')
        $Converted = $Converted.Replace('(' + $AgentBaseName + ')', '(`' + $CodexAgentName + '`)')
    }

    foreach ($SkillName in $SkillNames) {
        $Converted = $Converted.Replace("../$SkillName/", "../academic-workflow-$SkillName/")
        $Pattern = "(?<![A-Za-z0-9_.-])/" + [regex]::Escape($SkillName) + "\b"
        $Replacement = '$academic-workflow-' + $SkillName
        $Converted = [regex]::Replace($Converted, $Pattern, { param($Match) $Replacement })
    }

    return $Converted
}

function Install-GlobalAgentsBlock {
    $BlockPath = Join-Path $PackageRoot "templates\global-AGENTS.block.md"
    $Block = (Get-Content -LiteralPath $BlockPath -Raw -Encoding utf8).Trim()
    $StartMarker = "<!-- BEGIN academic-workflow -->"
    $EndMarker = "<!-- END academic-workflow -->"

    Ensure-Directory $CodexHomePath
    if (Test-Path -LiteralPath $GlobalAgentsPath) {
        Backup-File $GlobalAgentsPath
        $Existing = Get-Content -LiteralPath $GlobalAgentsPath -Raw -Encoding utf8
        if ($null -eq $Existing) { $Existing = "" }
        $Pattern = [regex]::Escape($StartMarker) + ".*?" + [regex]::Escape($EndMarker)
        if ([regex]::IsMatch($Existing, $Pattern, [Text.RegularExpressions.RegexOptions]::Singleline)) {
            $Merged = [regex]::Replace($Existing, $Pattern, $Block, [Text.RegularExpressions.RegexOptions]::Singleline)
        } else {
            $Merged = $Existing.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + $Block + [Environment]::NewLine
        }
    } else {
        $Merged = $Block + [Environment]::NewLine
    }
    Write-Utf8Text -Path $GlobalAgentsPath -Value $Merged
}

function Resolve-SourceRepository {
    if ($SourcePath) {
        $Resolved = (Resolve-Path -LiteralPath $SourcePath).Path
        if (-not (Test-Path -LiteralPath (Join-Path $Resolved ".claude\skills"))) {
            throw "SourcePath does not contain .claude\skills: $Resolved"
        }
        return $Resolved
    }

    Ensure-Directory (Split-Path -Parent $VendorPath)
    if (Test-Path -LiteralPath (Join-Path $VendorPath ".git")) {
        Invoke-GitChecked -Arguments @("-C", $VendorPath, "fetch", "--prune", "origin") -FailureMessage "Could not fetch the vendor source at $VendorPath"
    } elseif (Test-Path -LiteralPath $VendorPath) {
        throw "Vendor target already exists but is not a Git repository: $VendorPath"
    } else {
        Invoke-GitChecked -Arguments @("clone", $RepositoryUrl, $VendorPath) -FailureMessage "Could not clone $RepositoryUrl"
    }
    Invoke-GitChecked -Arguments @("-C", $VendorPath, "checkout", "--detach", $RepositoryRef) -FailureMessage "Could not check out pinned upstream ref $RepositoryRef"
    return $VendorPath
}

function Install-CoreSkill {
    param([Parameter(Mandatory)][string]$SourceRoot)

    $CorePath = Join-Path $UserSkillsPath "academic-workflow-core"
    $ReferencesPath = Join-Path $CorePath "references"
    $AssetsPath = Join-Path $CorePath "assets"
    Ensure-Directory (Join-Path $ReferencesPath "rules")
    Ensure-Directory (Join-Path $ReferencesPath "upstream")
    Ensure-Directory (Join-Path $ReferencesPath "codex")
    Ensure-Directory (Join-Path $AssetsPath "templates")

    $CoreSkill = @'
---
name: academic-workflow-core
description: Coordinate rigorous academic work using scoped planning, evidence checks, independent review, fixes, and final verification. Use for complex papers, slides, data analyses, replication packages, and research workflows.
---

# Academic Workflow Core

1. Resolve deliverables, inputs, constraints, assumptions, and acceptance checks.
2. Inspect the actual repository and preserve unrelated changes.
3. Separate implementation, verification, and independent review.
4. Delegate only independent bounded work and require evidence-backed findings.
5. Fix confirmed critical and major issues, rerun checks, and repeat until dry or a five-round safety cap is reached.
6. Report unresolved disagreement, missing inputs, unavailable tools, and failed checks honestly.
7. Save durable review evidence under `quality_reports/` when that convention is present.

Load `references/codex/folder-organization.md` whenever deciding where to create, move, or save research data, code, figures, tables, temporary files, or documents. Load only other relevant files under `references/` for the current task. Project-specific paths and commands belong in the repository `AGENTS.md`.
'@
    Write-Utf8Text -Path (Join-Path $CorePath "SKILL.md") -Value $CoreSkill

    $SourceRules = Join-Path $SourceRoot ".claude\rules"
    $SourceReferences = Join-Path $SourceRoot ".claude\references"
    if (Test-Path -LiteralPath $SourceRules) {
        Copy-Item -Path (Join-Path $SourceRules "*") -Destination (Join-Path $ReferencesPath "rules") -Recurse -Force
    }
    if (Test-Path -LiteralPath $SourceReferences) {
        Copy-Item -Path (Join-Path $SourceReferences "*") -Destination (Join-Path $ReferencesPath "upstream") -Recurse -Force
    }
    $SourceTemplates = Join-Path $SourceRoot "templates"
    if (Test-Path -LiteralPath $SourceTemplates) {
        Copy-Item -Path (Join-Path $SourceTemplates "*") -Destination (Join-Path $AssetsPath "templates") -Recurse -Force
    }
    $SourcePreambles = Join-Path $SourceRoot "Preambles"
    if (Test-Path -LiteralPath $SourcePreambles) {
        Ensure-Directory (Join-Path $AssetsPath "Preambles")
        Copy-Item -Path (Join-Path $SourcePreambles "*") -Destination (Join-Path $AssetsPath "Preambles") -Recurse -Force
    }
    $SourceQuarto = Join-Path $SourceRoot "Quarto"
    if (Test-Path -LiteralPath $SourceQuarto) {
        Ensure-Directory (Join-Path $AssetsPath "Quarto")
        Copy-Item -Path (Join-Path $SourceQuarto "*") -Destination (Join-Path $AssetsPath "Quarto") -Recurse -Force
    }
    $SourceChangelog = Join-Path $SourceRoot "CHANGELOG.md"
    if (Test-Path -LiteralPath $SourceChangelog -PathType Leaf) {
        $LegacyChangelog = Join-Path $ReferencesPath "CHANGELOG.md"
        if (Test-Path -LiteralPath $LegacyChangelog -PathType Leaf) {
            Backup-File $LegacyChangelog
            Remove-Item -LiteralPath $LegacyChangelog -Force
        }
        Copy-Item -LiteralPath $SourceChangelog -Destination (Join-Path $ReferencesPath "upstream\CHANGELOG.md") -Force
    }

    $SkillNames = @(Get-ChildItem -LiteralPath (Join-Path $SourceRoot ".claude\skills") -Directory | ForEach-Object Name)
    $AssetTextFiles = Get-ChildItem -LiteralPath (Join-Path $AssetsPath "templates") -Recurse -File | Where-Object Extension -In @(".md", ".txt", ".yaml", ".yml")
    foreach ($AssetFile in $AssetTextFiles) {
        $AssetText = Get-Content -LiteralPath $AssetFile.FullName -Raw -Encoding utf8
        $AssetText = [regex]::Replace(
            $AssetText,
            '\[[^\]]+\]\([^)]*\.claude/rules/([^\)#]+)(?:#[^)]+)?\)',
            { param($Match) '`academic-workflow-core` rule `' + $Match.Groups[1].Value + '`' }
        )
        $AssetText = [regex]::Replace(
            $AssetText,
            '\[[^\]]+\]\([^)]*\.claude/references/([^\)#]+)(?:#[^)]+)?\)',
            { param($Match) '`academic-workflow-core` reference `' + $Match.Groups[1].Value + '`' }
        )
        $AssetText = $AssetText.Replace(".claude/rules/", "__ASSET_RULE__/")
        $AssetText = $AssetText.Replace(".claude/references/", "__ASSET_REFERENCE__/")
        $AssetText = Convert-ClaudeText -Text $AssetText -SkillNames $SkillNames
        $AssetText = $AssetText.Replace("__ASSET_RULE__/", "academic-workflow-core rule ")
        $AssetText = $AssetText.Replace("__ASSET_REFERENCE__/", "academic-workflow-core reference ")
        $AssetText = $AssetText.Replace('Copy this file to `academic-workflow-core rule constitutional-governance.md`', 'Adapt this file into the repository `AGENTS.md` or a checked-in governance document referenced from it')
        $AssetText = $AssetText.Replace('File saved to `academic-workflow-core rule constitutional-governance.md`', 'Governance decisions recorded in project `AGENTS.md` or linked project documentation')
        Write-Utf8Text -Path $AssetFile.FullName -Value $AssetText
    }
    Copy-Item -LiteralPath (Join-Path $PackageRoot "templates\codex-skill-template.md") -Destination (Join-Path $AssetsPath "templates\skill-template.md") -Force
    $CodexReferences = Join-Path $PackageRoot "templates\codex-references"
    if (Test-Path -LiteralPath $CodexReferences -PathType Container) {
        Copy-Item -Path (Join-Path $CodexReferences "*") -Destination (Join-Path $ReferencesPath "codex") -Recurse -Force
    }

    foreach ($ReferenceFile in Get-ChildItem -LiteralPath $ReferencesPath -Recurse -Filter "*.md" -File) {
        $Original = Get-Content -LiteralPath $ReferenceFile.FullName -Raw -Encoding utf8
        $IsRule = $ReferenceFile.FullName.StartsWith((Join-Path $ReferencesPath "rules"), [StringComparison]::OrdinalIgnoreCase)

        $Protected = $Original.Replace(".claude/rules/", "__ACADEMIC_RULES__/")
        $Protected = $Protected.Replace("../../rules/", "__ACADEMIC_RULES__/")
        $Protected = $Protected.Replace(".claude/references/", "__ACADEMIC_REFERENCES__/")
        $Protected = $Protected.Replace("../../references/", "__ACADEMIC_REFERENCES__/")
        $ConvertedReference = Convert-ClaudeText -Text $Protected -SkillNames $SkillNames
        $ConvertedReference = [regex]::Replace(
            $ConvertedReference,
            '\[[^\]]+\]\(\.\./hooks/([^)]+)\)',
            { param($Match) '`Codex hook ' + $Match.Groups[1].Value + '` under `~/.codex/hooks/academic-workflow/`' }
        )
        $ConvertedReference = [regex]::Replace(
            $ConvertedReference,
            '\.\./skills/([a-z0-9-]+)/SKILL\.md',
            { param($Match) '../../../academic-workflow-' + $Match.Groups[1].Value + '/SKILL.md' }
        )

        if ($IsRule) {
            $ConvertedReference = $ConvertedReference.Replace("../../CHANGELOG.md", "../upstream/CHANGELOG.md")
            $ConvertedReference = Remove-Frontmatter $ConvertedReference
            $ConvertedReference = $ConvertedReference.Replace("__ACADEMIC_RULES__/", "./")
            $ConvertedReference = $ConvertedReference.Replace("__ACADEMIC_REFERENCES__/", "../upstream/")
            $ConvertedReference = $ConvertedReference.Replace("../references/", "../upstream/")
        } else {
            $ConvertedReference = $ConvertedReference.Replace("../../CHANGELOG.md", "./CHANGELOG.md")
            $ConvertedReference = $ConvertedReference.Replace("__ACADEMIC_RULES__/", "../rules/")
            $ConvertedReference = $ConvertedReference.Replace("__ACADEMIC_REFERENCES__/", "./")
            $ConvertedReference = $ConvertedReference.Replace("../references/", "./")
        }

        if ($ConvertedReference -ne $Original) {
            $ReferenceNote = '> Codex port note: This reference was adapted from the upstream workflow. Use active Codex configuration under `~/.codex`, user skills under `~/.agents/skills`, native hooks under `~/.codex/hooks/academic-workflow`, and the named `academic_*` custom agents.' + [Environment]::NewLine + [Environment]::NewLine
            $ConvertedReference = $ReferenceNote + $ConvertedReference
        }
        Write-Utf8Text -Path $ReferenceFile.FullName -Value $ConvertedReference
    }
}

function Install-ConvertedSkills {
    param([Parameter(Mandatory)][string]$SourceRoot)

    $SkillsSource = Join-Path $SourceRoot ".claude\skills"
    $SkillDirectories = @(Get-ChildItem -LiteralPath $SkillsSource -Directory | Sort-Object Name)
    $SkillNames = @($SkillDirectories | ForEach-Object { $_.Name })

    foreach ($SkillDirectory in $SkillDirectories) {
        $SourceSkillFile = Join-Path $SkillDirectory.FullName "SKILL.md"
        if (-not (Test-Path -LiteralPath $SourceSkillFile)) { continue }

        $DestinationName = "academic-workflow-$($SkillDirectory.Name)"
        $DestinationPath = Join-Path $UserSkillsPath $DestinationName
        Ensure-Directory $DestinationPath
        foreach ($SupportItem in Get-ChildItem -LiteralPath $SkillDirectory.FullName -Force | Where-Object Name -ne "SKILL.md") {
            Copy-Item -LiteralPath $SupportItem.FullName -Destination $DestinationPath -Recurse -Force
        }

        $Original = Get-Content -LiteralPath $SourceSkillFile -Raw -Encoding utf8
        $Description = Get-FrontmatterValue -Text $Original -Key "description"
        if (-not $Description) { $Description = "Academic workflow adapted from the upstream $($SkillDirectory.Name) skill." }
        $Description = Convert-ClaudeText -Text $Description -SkillNames $SkillNames
        $Description = $Description.Replace("WebSearch/WebFetch", "web search and page retrieval")
        $Description = $Description.Replace("Claude Code", "Codex")
        $Description = $Description.Replace("<", "").Replace(">", "")
        $Body = Remove-Frontmatter $Original
        $Body = Convert-ClaudeText -Text $Body -SkillNames $SkillNames
        $DescriptionJson = ConvertTo-Json ("Codex port: " + $Description) -Compress
        $Compatibility = '> Codex port note: invoke this skill as $' + $DestinationName + '. Treat `<user-input>` as a placeholder for the relevant value from the user prompt and substitute the actual value before running commands. Use the current operating system''s shell syntax and Codex filesystem, web, planning, background-process, and subagent tools. Resolve relative project paths from the current Git repository. If an optional upstream reference or project asset is absent, report it and continue with the parts that can be verified.' + [Environment]::NewLine + [Environment]::NewLine
        $Converted = "---`nname: $DestinationName`ndescription: $DescriptionJson`n---`n`n" + $Compatibility + $Body
        Write-Utf8Text -Path (Join-Path $DestinationPath "SKILL.md") -Value $Converted
    }
}

function Install-ConvertedAgents {
    param([Parameter(Mandatory)][string]$SourceRoot)

    $AgentsSource = Join-Path $SourceRoot ".claude\agents"
    $SkillNames = @(Get-ChildItem -LiteralPath (Join-Path $SourceRoot ".claude\skills") -Directory | ForEach-Object Name)
    Ensure-Directory $GlobalCustomAgentsPath
    foreach ($AgentFile in Get-ChildItem -LiteralPath $AgentsSource -Filter "*.md" -File | Sort-Object Name) {
        $Original = Get-Content -LiteralPath $AgentFile.FullName -Raw -Encoding utf8
        $BaseName = [IO.Path]::GetFileNameWithoutExtension($AgentFile.Name)
        $AgentName = "academic_" + ($BaseName -replace "-", "_")
        $Description = Get-FrontmatterValue -Text $Original -Key "description"
        if (-not $Description) { $Description = "Academic specialist adapted from the upstream $BaseName agent." }
        $Description = Convert-ClaudeText -Text $Description -SkillNames $SkillNames
        $Body = Remove-Frontmatter $Original
        $Body = Convert-ClaudeText -Text $Body -SkillNames $SkillNames
        $Sandbox = if ($BaseName -match "fixer|translator") { "workspace-write" } else { "read-only" }
        $DescriptionToml = ConvertTo-Json ("Codex port: " + $Description) -Compress
        $InstructionsToml = ConvertTo-Json $Body -Compress
        $Toml = @"
name = "$AgentName"
description = $DescriptionToml
sandbox_mode = "$Sandbox"
developer_instructions = $InstructionsToml
"@
        $Destination = Join-Path $GlobalCustomAgentsPath ($AgentName + ".toml")
        Backup-File $Destination
        Write-Utf8Text -Path $Destination -Value $Toml
    }
}

function Install-CodexSkillOverrides {
    $OverrideRoot = Join-Path $PackageRoot "templates\skill-overrides"
    if (-not (Test-Path -LiteralPath $OverrideRoot -PathType Container)) { return }

    foreach ($OverrideFile in Get-ChildItem -LiteralPath $OverrideRoot -Filter "*.md" -File | Sort-Object Name) {
        $SkillName = [IO.Path]::GetFileNameWithoutExtension($OverrideFile.Name)
        $DestinationPath = Join-Path $UserSkillsPath $SkillName
        Ensure-Directory $DestinationPath
        $OverrideText = Get-Content -LiteralPath $OverrideFile.FullName -Raw -Encoding utf8
        Write-Utf8Text -Path (Join-Path $DestinationPath "SKILL.md") -Value $OverrideText
    }
}

function Install-CodexOnlySkills {
    $SourceRoot = Join-Path $PackageRoot "templates\codex-only-skills"
    if (-not (Test-Path -LiteralPath $SourceRoot -PathType Container)) { return }

    foreach ($SkillDirectory in Get-ChildItem -LiteralPath $SourceRoot -Directory | Sort-Object Name) {
        $SkillFile = Join-Path $SkillDirectory.FullName "SKILL.md"
        if (-not (Test-Path -LiteralPath $SkillFile -PathType Leaf)) { continue }
        $Destination = Join-Path $UserSkillsPath $SkillDirectory.Name
        Ensure-Directory $Destination
        Copy-Item -Path (Join-Path $SkillDirectory.FullName "*") -Destination $Destination -Recurse -Force
    }
}

function Test-AcademicHookGroup {
    param([Parameter(Mandatory)]$Group)
    if (-not $Group -or -not $Group.PSObject.Properties['hooks']) { return $false }
    foreach ($Handler in @($Group.PSObject.Properties['hooks'].Value)) {
        $Commands = @()
        foreach ($PropertyName in @('command', 'commandWindows', 'command_windows')) {
            $Property = $Handler.PSObject.Properties[$PropertyName]
            if ($Property -and $Property.Value) { $Commands += $Property.Value }
        }
        foreach ($Command in $Commands) {
            if ($Command -match '[\\/]academic-workflow[\\/]') { return $true }
        }
    }
    return $false
}

function Install-CodexHooks {
    if ($SkipHooks) { return }

    $HookSource = Join-Path $PackageRoot "templates\hooks"
    if (-not (Test-Path -LiteralPath $HookSource -PathType Container)) {
        throw "Hook templates are missing: $HookSource"
    }

    Ensure-Directory $GlobalHooksPath
    foreach ($HookFile in Get-ChildItem -LiteralPath $HookSource -File | Sort-Object Name) {
        $Destination = Join-Path $GlobalHooksPath $HookFile.Name
        Backup-File $Destination
        Copy-Item -LiteralPath $HookFile.FullName -Destination $Destination -Force
    }

    Backup-File $GlobalHooksConfigPath
    if (Test-Path -LiteralPath $GlobalHooksConfigPath -PathType Leaf) {
        $HooksConfig = Get-Content -LiteralPath $GlobalHooksConfigPath -Raw -Encoding utf8 | ConvertFrom-Json
    } else {
        $HooksConfig = [pscustomobject]@{ description = "User-level Codex hooks"; hooks = [pscustomobject]@{} }
    }
    if (-not $HooksConfig.PSObject.Properties['hooks']) {
        $HooksConfig | Add-Member -MemberType NoteProperty -Name hooks -Value ([pscustomobject]@{})
    }

    $Python = Get-Command python -ErrorAction SilentlyContinue
    if (-not $Python) { $Python = Get-Command py -ErrorAction SilentlyContinue }
    if (-not $Python) {
        throw "Python 3 is required for the Codex academic workflow hooks. Install Python, or rerun with -SkipHooks."
    }
    $PythonCommand = if ($Python.Name -eq 'py.exe' -or $Python.Name -eq 'py') { 'py -3' } else { '"' + $Python.Source + '"' }
    $PosixRoot = '$HOME/.codex/hooks/academic-workflow'

    $Definitions = @(
        [pscustomobject]@{ Event = 'PreToolUse'; Matcher = '^(Bash|apply_patch|Edit|Write)$'; Script = 'git_guardrails.py'; Status = 'Checking academic workflow guardrails'; Timeout = 10; AllowsAdditionalContext = $true },
        [pscustomobject]@{ Event = 'PostToolUse'; Matcher = '^(apply_patch|Edit|Write)$'; Script = 'claim_reconcile.py'; Status = 'Checking tracked claim provenance'; Timeout = 10; AllowsAdditionalContext = $true },
        [pscustomobject]@{ Event = 'PreCompact'; Matcher = '^(manual|auto)$'; Script = 'pre_compact.py'; Status = 'Saving academic workflow state'; Timeout = 10; AllowsAdditionalContext = $false },
        [pscustomobject]@{ Event = 'SessionStart'; Matcher = '^(compact|resume)$'; Script = 'post_compact_restore.py'; Status = 'Restoring academic workflow state'; Timeout = 10; AllowsAdditionalContext = $true },
        [pscustomobject]@{ Event = 'Stop'; Matcher = $null; Script = 'session_log.py'; Status = 'Updating the academic session log'; Timeout = 15; AllowsAdditionalContext = $false }
    )

    foreach ($Definition in $Definitions) {
        $ScriptPath = Join-Path $GlobalHooksPath $Definition.Script
        $Handler = [ordered]@{
            type = 'command'
            command = 'python3 "' + $PosixRoot + '/' + $Definition.Script + '"'
            commandWindows = $PythonCommand + ' "' + $ScriptPath + '"'
            timeout = $Definition.Timeout
            statusMessage = $Definition.Status
        }
        if ($Definition.AllowsAdditionalContext) { $Handler.additionalContextLimit = 2500 }
        $Group = [ordered]@{ hooks = @([pscustomobject]$Handler) }
        if ($Definition.Matcher) { $Group = [ordered]@{ matcher = $Definition.Matcher; hooks = @([pscustomobject]$Handler) } }

        $Property = $HooksConfig.hooks.PSObject.Properties[$Definition.Event]
        $Existing = if ($Property) { @($Property.Value) } else { @() }
        $Preserved = @($Existing | Where-Object { -not (Test-AcademicHookGroup $_) })
        $Updated = @($Preserved + [pscustomobject]$Group)
        if ($Property) {
            $Property.Value = $Updated
        } else {
            $HooksConfig.hooks | Add-Member -MemberType NoteProperty -Name $Definition.Event -Value $Updated
        }
    }

    Write-Utf8Text -Path $GlobalHooksConfigPath -Value ($HooksConfig | ConvertTo-Json -Depth 20)
}

function Install-CliUiDefaults {
    if ($SkipCliUiDefaults) { return }
    $StatusLine = 'status_line = ["model-with-reasoning", "context-remaining", "git-branch", "current-dir"]'
    if (Test-Path -LiteralPath $GlobalConfigPath -PathType Leaf) {
        $ConfigText = Get-Content -LiteralPath $GlobalConfigPath -Raw -Encoding utf8
        if ([regex]::IsMatch($ConfigText, '(?m)^\s*status_line\s*=')) { return }
        Backup-File $GlobalConfigPath
        $TuiMatch = [regex]::Match($ConfigText, '(?m)^\[tui\]\s*$')
        if ($TuiMatch.Success) {
            $InsertAt = $TuiMatch.Index + $TuiMatch.Length
            $ConfigText = $ConfigText.Insert($InsertAt, [Environment]::NewLine + '# Added by the Codex academic workflow installer.' + [Environment]::NewLine + $StatusLine)
        } else {
            $ConfigText = $ConfigText.TrimEnd() + [Environment]::NewLine + [Environment]::NewLine + '[tui]' + [Environment]::NewLine + '# Added by the Codex academic workflow installer.' + [Environment]::NewLine + $StatusLine + [Environment]::NewLine
        }
    } else {
        $ConfigText = '[tui]' + [Environment]::NewLine + '# Added by the Codex academic workflow installer.' + [Environment]::NewLine + $StatusLine + [Environment]::NewLine
    }
    Write-Utf8Text -Path $GlobalConfigPath -Value $ConfigText
}

function Install-PersonalWorkflowState {
    $StateRoot = Join-Path $CodexHomePath "academic-workflow-state"
    $MemoryPath = Join-Path $StateRoot "personal-memory.md"
    Ensure-Directory $StateRoot
    if (-not (Test-Path -LiteralPath $MemoryPath -PathType Leaf)) {
        $MemoryText = @'
# Personal academic workflow memory

Store machine-specific or personal reusable lessons here. Keep project facts in the nearest project `AGENTS.md` or checked-in project documentation.
'@
        Write-Utf8Text -Path $MemoryPath -Value $MemoryText
    }
}

function Install-SafetyRules {
    Ensure-Directory $GlobalRulesPath
    $Destination = Join-Path $GlobalRulesPath "academic-workflow.rules"
    Backup-File $Destination
    Copy-Item -LiteralPath (Join-Path $PackageRoot "templates\academic-workflow.rules") -Destination $Destination -Force
}

function Install-ProjectInitializer {
    param([Parameter(Mandatory)][string]$SourceRoot)

    $SkillPath = Join-Path $UserSkillsPath "academic-workflow-init"
    $AssetsPath = Join-Path $SkillPath "assets"
    $ScriptsPath = Join-Path $SkillPath "scripts"
    Ensure-Directory $AssetsPath
    Ensure-Directory $ScriptsPath
    Copy-Item -LiteralPath (Join-Path $PackageRoot "templates\project-AGENTS.md") -Destination (Join-Path $AssetsPath "project-AGENTS.md") -Force
    Copy-Item -LiteralPath (Join-Path $PackageRoot "templates\project-MEMORY.md") -Destination (Join-Path $AssetsPath "project-MEMORY.md") -Force
    $ProjectScriptsSource = Join-Path $PackageRoot "templates\project-scripts"
    $ProjectScriptsDestination = Join-Path $AssetsPath "project-scripts"
    Ensure-Directory $ProjectScriptsDestination
    if (Test-Path -LiteralPath $ProjectScriptsSource -PathType Container) {
        Copy-Item -Path (Join-Path $ProjectScriptsSource "*") -Destination $ProjectScriptsDestination -Recurse -Force
    }

    $InitTemplate = Get-Content -LiteralPath (Join-Path $PackageRoot "templates\init-project.ps1.template") -Raw -Encoding utf8
    $InitScript = $InitTemplate.Replace('__SOURCE_ROOT__', $SourceRoot.Replace("'", "''"))
    $InitScript = $InitScript.Replace('__CORE_TEMPLATES_ROOT__', (Join-Path $UserSkillsPath "academic-workflow-core\assets\templates").Replace("'", "''"))
    Write-Utf8Text -Path (Join-Path $ScriptsPath "init-project.ps1") -Value $InitScript

    $SkillText = @'
---
name: academic-workflow-init
description: Initialize the current repository for the global Codex academic workflow without overwriting existing project files. Use when starting or adopting a paper, lecture, analysis, or replication project.
---

# Initialize an academic project

1. Inspect the repository and identify any existing `AGENTS.md`, document sources, analysis scripts, templates, and build commands.
2. Run `scripts/init-project.ps1` from this skill directory with the repository root as `-ProjectPath`. It merges only missing scaffold files and never overwrites existing project files.
3. Use `-IncludeAutomation` only when the user wants upstream `.github`, `.githooks`, and `.vscode` templates added; inspect them before enabling a Git hook or CI workflow.
4. Customize the resulting project `AGENTS.md` with the real project identity, canonical files, commands, and verification criteria.
5. Inspect the project's actual dependencies and run its real build or analysis checks when available. Report missing optional tools honestly.
6. Report created files, preserved files, missing dependencies, and the recommended first workflow skill.

The initializer also creates `.codex/academic-workflow.json` and the default `data/source/output` stage mirror plus `temp/` and `documents/`. Global academic hooks use the marker to avoid writing logs or project state in unrelated repositories.
'@
    Write-Utf8Text -Path (Join-Path $SkillPath "SKILL.md") -Value $SkillText
}

Ensure-Directory $CodexHomePath
Ensure-Directory $UserSkillsPath
$ResolvedSource = Resolve-SourceRepository
$SourceCommit = $null
if (Test-Path -LiteralPath (Join-Path $ResolvedSource ".git")) {
    $SourceCommitOutput = & git -C $ResolvedSource rev-parse HEAD 2>&1
    if ($LASTEXITCODE -eq 0) { $SourceCommit = ($SourceCommitOutput | Select-Object -First 1).ToString().Trim() }
}
$PackageVersion = if (Test-Path -LiteralPath (Join-Path $PackageRoot "VERSION")) {
    (Get-Content -LiteralPath (Join-Path $PackageRoot "VERSION") -Raw -Encoding utf8).Trim()
} else { "development" }

if (-not $SkipGlobalAgentsBlock) {
    Install-GlobalAgentsBlock
    if (Test-Path -LiteralPath $GlobalAgentsOverridePath -PathType Leaf) {
        $OverrideText = Get-Content -LiteralPath $GlobalAgentsOverridePath -Raw -Encoding utf8
        if ($OverrideText -and $OverrideText.Trim()) {
            Write-Warning "A non-empty $GlobalAgentsOverridePath takes precedence over AGENTS.md. Merge the academic workflow block there if you want the global guidance to be active."
        }
    }
}
Install-CoreSkill -SourceRoot $ResolvedSource
Install-ConvertedSkills -SourceRoot $ResolvedSource
Install-CodexSkillOverrides
Install-CodexOnlySkills
Install-ConvertedAgents -SourceRoot $ResolvedSource
Install-SafetyRules
Install-ProjectInitializer -SourceRoot $ResolvedSource
Install-PersonalWorkflowState
Install-CodexHooks
Install-CliUiDefaults

$Manifest = [ordered]@{
    installed_at = (Get-Date).ToString("o")
    source = $ResolvedSource
    repository_url = $RepositoryUrl
    repository_ref = if ($SourcePath) { $null } else { $RepositoryRef }
    source_commit = $SourceCommit
    package_version = $PackageVersion
    skills_root = $UserSkillsPath
    agents_root = $GlobalCustomAgentsPath
    rules_file = (Join-Path $GlobalRulesPath "academic-workflow.rules")
    hooks_root = if ($SkipHooks) { $null } else { $GlobalHooksPath }
    hooks_config = if ($SkipHooks) { $null } else { $GlobalHooksConfigPath }
    cli_ui_defaults_installed = (-not $SkipCliUiDefaults)
    personal_memory_file = (Join-Path $CodexHomePath "academic-workflow-state\personal-memory.md")
    backup_root = $BackupPath
}
$ManifestJson = $Manifest | ConvertTo-Json -Depth 4
Write-Utf8Text -Path (Join-Path $CodexHomePath "academic-workflow-install.json") -Value $ManifestJson

Write-Host "Installed the Codex academic workflow."
Write-Host "Restart Codex, then invoke `$academic-workflow-init in a target repository."
if (-not $SkipHooks) { Write-Host "In the Codex CLI, run /hooks and review/trust the five academic workflow hook definitions." }
if (Test-Path -LiteralPath $BackupPath) { Write-Host "Backups: $BackupPath" }
