[CmdletBinding()]
param(
    [string]$SourcePath,
    [string]$RepositoryUrl = "https://github.com/pedrohcgs/claude-code-my-workflow.git",
    [string]$RepositoryRef = "be53c12f235996dff41fb7f21580506fd2dd8d50",
    [switch]$BypassGitHubProxy,
    [switch]$SkipGlobalAgentsBlock
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$UserProfilePath = [Environment]::GetFolderPath("UserProfile")
$CodexHomePath = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $UserProfilePath ".codex" }
$UserSkillsPath = Join-Path $UserProfilePath ".agents\skills"
$VendorPath = Join-Path $CodexHomePath "vendor\academic-workflow"
$GlobalAgentsPath = Join-Path $CodexHomePath "AGENTS.md"
$GlobalAgentsOverridePath = Join-Path $CodexHomePath "AGENTS.override.md"
$GlobalCustomAgentsPath = Join-Path $CodexHomePath "agents"
$GlobalRulesPath = Join-Path $CodexHomePath "rules"
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
    $SafeName = ($Path -replace "[:\\/]", "_").TrimStart("_")
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
    $Converted = $Converted.Replace('$ARGUMENTS', "the arguments and context supplied by the user")
    $Converted = $Converted.Replace('$CLAUDE_PROJECT_DIR', "the current Git repository root")
    $Converted = $Converted.Replace(".claude/rules/", "../academic-workflow-core/references/rules/")
    $Converted = $Converted.Replace("../../rules/", "../academic-workflow-core/references/rules/")
    $Converted = $Converted.Replace(".claude/references/", "../academic-workflow-core/references/upstream/")
    $Converted = $Converted.Replace("../../references/", "../academic-workflow-core/references/upstream/")
    $Converted = $Converted.Replace("../../../templates/", "../academic-workflow-core/assets/templates/")
    $Converted = $Converted.Replace("Task tool", "Codex subagent tools")
    $Converted = $Converted.Replace("via Task", "with a Codex subagent")
    $Converted = $Converted.Replace('`Task`', "Codex subagent delegation")
    $Converted = $Converted.Replace("WebSearch", "web search")
    $Converted = $Converted.Replace("WebFetch", "page retrieval")
    $Converted = $Converted.Replace("Opus", "a high-judgment Codex model")
    $Converted = $Converted.Replace("Sonnet", "a balanced Codex model")
    $Converted = $Converted.Replace("Haiku", "a fast Codex model")
    $Converted = $Converted.Replace("[Claude Code](https://claude.com/claude-code)", "Codex")
    $Converted = $Converted.Replace("Claude Code", "Codex")
    $Converted = $Converted.Replace("CLAUDE.md", "AGENTS.md")
    $Converted = $Converted.Replace(".claude/state/personal-memory.md", "~/.codex/academic-workflow-state/personal-memory.md")
    $Converted = $Converted.Replace(".claude/state/", "~/.codex/academic-workflow-state/")
    $Converted = $Converted.Replace("PreCompact hook", "context-pressure handoff")
    $Converted = $Converted.Replace("the PreCompact hook", "a context-pressure handoff")
    $Converted = [regex]::Replace(
        $Converted,
        '(?m)^- `\.claude/hooks/pre-compact\.py`.*$',
        '- Run `$academic-workflow-compress-session` before a long-session handoff or when context pressure becomes apparent.'
    )
    $Converted = [regex]::Replace(
        $Converted,
        ' or sets `verifyClaims\.allowHighWarn: true` in `\.claude/settings\.json`',
        ''
    )

    $Converted = [regex]::Replace(
        $Converted,
        '\[`?\.claude/agents/([a-z0-9-]+)\.md`?\]\((?:\.\./)+agents/\1\.md\)',
        { param($Match) "academic_" + $Match.Groups[1].Value.Replace("-", "_") + " custom agent" }
    )
    $Converted = [regex]::Replace(
        $Converted,
        '(?:\.claude/agents/|(?:\.\./)+agents/)([a-z0-9-]+)\.md',
        { param($Match) "academic_" + $Match.Groups[1].Value.Replace("-", "_") + " custom agent" }
    )
    $Converted = [regex]::Replace(
        $Converted,
        '\[[^\]]+\]\((academic_[a-z0-9_]+) custom agent\)',
        { param($Match) '`' + $Match.Groups[1].Value + '` custom agent' }
    )
    $Converted = [regex]::Replace(
        $Converted,
        '\.claude/skills/([a-z0-9-]+)(?:/SKILL\.md)?',
        { param($Match) '$academic-workflow-' + $Match.Groups[1].Value }
    )
    $Converted = $Converted.Replace(".claude/skills/", "~/.agents/skills/")
    $Converted = $Converted.Replace(".claude/agents/", "~/.codex/agents/")
    $Converted = $Converted.Replace(".claude/hooks/", "upstream hook script ")
    $Converted = $Converted.Replace(".claude/settings.local.json", ".codex/config.toml")
    $Converted = $Converted.Replace(".claude/settings.json", "~/.codex/config.toml")

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

Load only the relevant files under `references/` for the current task. Project-specific paths and commands belong in the repository `AGENTS.md`.
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
            { param($Match) '`upstream hook ' + $Match.Groups[1].Value + '` (not installed)' }
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
            $ReferenceNote = '> Codex port note: This reference was adapted from the upstream Claude workflow. Use active Codex configuration under `~/.codex`, user skills under `~/.agents/skills`, and the named `academic_*` custom agents. Any hook-specific discussion is methodological or upstream background unless a Codex hook is explicitly installed.' + [Environment]::NewLine + [Environment]::NewLine
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
        $Compatibility = '> Codex port note: invoke this skill as $' + $DestinationName + '. Use Codex filesystem, shell, web, planning, and subagent tools rather than Claude-specific tool names. Resolve relative project paths from the current Git repository. If an optional upstream reference or project asset is absent, report it and continue with the parts that can be verified.' + [Environment]::NewLine + [Environment]::NewLine
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

    $EscapedSource = $SourceRoot.Replace("'", "''")
    $EscapedCoreTemplates = (Join-Path $UserSkillsPath "academic-workflow-core\assets\templates").Replace("'", "''")
    $InitScript = @"
[CmdletBinding()]
param([string]`$ProjectPath = (Get-Location).Path)
Set-StrictMode -Version Latest
`$ErrorActionPreference = "Stop"
`$SourceRoot = '$EscapedSource'
`$CoreTemplatesRoot = '$EscapedCoreTemplates'
`$ProjectRoot = (Resolve-Path -LiteralPath `$ProjectPath).Path
`$SkillRoot = Split-Path -Parent (Split-Path -Parent `$MyInvocation.MyCommand.Path)

`$Directories = @("Preambles", "templates", "scripts", "Figures", "Slides", "Quarto", "master_supporting_docs")
foreach (`$Name in `$Directories) {
    `$Destination = Join-Path `$ProjectRoot `$Name
    if (`$Name -eq "scripts") {
        if (-not (Test-Path -LiteralPath `$Destination)) {
            New-Item -ItemType Directory -Path `$Destination | Out-Null
            Write-Host "Created empty scripts directory"
        } else {
            Write-Host "Preserved existing scripts"
        }
        continue
    }
    `$Source = if (`$Name -eq "templates") { `$CoreTemplatesRoot } else { Join-Path `$SourceRoot `$Name }
    if ((Test-Path -LiteralPath `$Source) -and -not (Test-Path -LiteralPath `$Destination)) {
        Copy-Item -LiteralPath `$Source -Destination `$Destination -Recurse
        Write-Host "Created `$Name"
    } elseif (Test-Path -LiteralPath `$Destination) {
        Write-Host "Preserved existing `$Name"
    }
}

foreach (`$Name in @("quality_reports", "explorations")) {
    `$Destination = Join-Path `$ProjectRoot `$Name
    if (-not (Test-Path -LiteralPath `$Destination)) {
        New-Item -ItemType Directory -Path `$Destination | Out-Null
    }
}

`$AgentsTemplate = Get-Content -LiteralPath (Join-Path `$SkillRoot "assets\project-AGENTS.md") -Raw -Encoding utf8
`$AgentsDestination = Join-Path `$ProjectRoot "AGENTS.md"
if (-not (Test-Path -LiteralPath `$AgentsDestination)) {
    `$Utf8NoBom = New-Object Text.UTF8Encoding(`$false)
    [IO.File]::WriteAllText(`$AgentsDestination, `$AgentsTemplate, `$Utf8NoBom)
    Write-Host "Created AGENTS.md"
} else {
    Write-Host "Preserved existing AGENTS.md; merge project academic instructions manually if needed."
}

Write-Host "Project initialization complete: `$ProjectRoot"
Write-Host "Next: customize AGENTS.md, record the project's real build and analysis commands, and invoke an academic-workflow skill."
"@
    Write-Utf8Text -Path (Join-Path $ScriptsPath "init-project.ps1") -Value $InitScript

    $SkillText = @'
---
name: academic-workflow-init
description: Initialize the current repository for the global Codex academic workflow without overwriting existing project files. Use when starting or adopting a paper, lecture, analysis, or replication project.
---

# Initialize an academic project

1. Inspect the repository and identify any existing `AGENTS.md`, document sources, analysis scripts, templates, and build commands.
2. Run `scripts/init-project.ps1` from this skill directory with the repository root as `-ProjectPath`.
3. Customize the resulting project `AGENTS.md` with the real project identity, canonical files, commands, and verification criteria.
4. Inspect the project's actual dependencies and run its real build or analysis checks when available. Report missing optional tools honestly.
5. Report created files, preserved files, missing dependencies, and the recommended first workflow skill.

Do not overwrite existing project directories or instructions automatically.
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
Install-ConvertedAgents -SourceRoot $ResolvedSource
Install-SafetyRules
Install-ProjectInitializer -SourceRoot $ResolvedSource
Install-PersonalWorkflowState

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
    personal_memory_file = (Join-Path $CodexHomePath "academic-workflow-state\personal-memory.md")
    backup_root = $BackupPath
}
$ManifestJson = $Manifest | ConvertTo-Json -Depth 4
Write-Utf8Text -Path (Join-Path $CodexHomePath "academic-workflow-install.json") -Value $ManifestJson

Write-Host "Installed the Codex academic workflow."
Write-Host "Restart Codex, then invoke `$academic-workflow-init in a target repository."
if (Test-Path -LiteralPath $BackupPath) { Write-Host "Backups: $BackupPath" }
