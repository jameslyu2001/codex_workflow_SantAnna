[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$UserProfilePath = [Environment]::GetFolderPath("UserProfile")
$CodexHomePath = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $UserProfilePath ".codex" }
$SkillsRoot = Join-Path $UserProfilePath ".agents\skills"
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Failures = [Collections.Generic.List[string]]::new()

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
Require-Path (Join-Path $CodexHomePath "academic-workflow-install.json") "installation manifest"
Require-Path (Join-Path $CodexHomePath "academic-workflow-state\personal-memory.md") "personal workflow memory"

$GlobalOverridePath = Join-Path $CodexHomePath "AGENTS.override.md"
if (Test-Path -LiteralPath $GlobalOverridePath -PathType Leaf) {
    $GlobalOverrideText = Get-Content -LiteralPath $GlobalOverridePath -Raw -Encoding utf8
    if ($GlobalOverrideText -and $GlobalOverrideText.Trim()) {
        Write-Warning "$GlobalOverridePath is non-empty and takes precedence over the installed global AGENTS.md."
    }
}

$ManifestPath = Join-Path $CodexHomePath "academic-workflow-install.json"
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
$ExpectedSkillCount = if (Test-Path -LiteralPath $VendorSkillsRoot) {
    @(Get-ChildItem -LiteralPath $VendorSkillsRoot -Directory).Count + 2
} else { 54 }
if ($SkillFiles.Count -eq $ExpectedSkillCount) { Write-Host "PASS  converted skill count" }
else { Write-Host "FAIL  converted skill count (expected $ExpectedSkillCount)"; $Failures.Add("converted skill count") }

foreach ($SkillFile in $SkillFiles) {
    $Text = Get-Content -LiteralPath $SkillFile.FullName -Raw -Encoding utf8
    if ($Text -notmatch '\A---\r?\nname:\s*[a-z0-9-]+\r?\ndescription:\s*.+?\r?\n---') {
        $Failures.Add("invalid skill frontmatter: $($SkillFile.FullName)")
    }
}
if (-not ($Failures | Where-Object { $_ -like "invalid skill frontmatter:*" })) { Write-Host "PASS  skill frontmatter" }

$AgentFiles = @(Get-ChildItem -LiteralPath (Join-Path $CodexHomePath "agents") -Filter "academic_*.toml" -File -ErrorAction SilentlyContinue)
Write-Host ("INFO  converted agents: " + $AgentFiles.Count)

$VendorAgentsRoot = Join-Path $CodexHomePath "vendor\academic-workflow\.claude\agents"
$ExpectedAgentCount = if (Test-Path -LiteralPath $VendorAgentsRoot) {
    @(Get-ChildItem -LiteralPath $VendorAgentsRoot -Filter "*.md" -File).Count
} else { 18 }
if ($AgentFiles.Count -eq $ExpectedAgentCount) { Write-Host "PASS  converted agent count" }
else { Write-Host "FAIL  converted agent count (expected $ExpectedAgentCount)"; $Failures.Add("converted agent count") }

foreach ($AgentFile in $AgentFiles) {
    $Text = Get-Content -LiteralPath $AgentFile.FullName -Raw -Encoding utf8
    foreach ($RequiredKey in @("name", "description", "developer_instructions")) {
        if ($Text -notmatch "(?m)^$RequiredKey\s*=") { $Failures.Add("agent missing $RequiredKey`: $($AgentFile.FullName)") }
    }
}
if (-not ($Failures | Where-Object { $_ -like "agent missing*" })) { Write-Host "PASS  agent required fields" }

$RulesPath = Join-Path $CodexHomePath "rules\academic-workflow.rules"
$CodexCommand = Get-Command codex -ErrorAction SilentlyContinue
if ($CodexCommand) {
    $PolicyOutput = & codex execpolicy check --pretty --rules $RulesPath git reset --hard HEAD~1 2>&1
    if ($LASTEXITCODE -eq 0 -and (($PolicyOutput -join [Environment]::NewLine) | ConvertFrom-Json).decision -eq "forbidden") {
        Write-Host "PASS  executable Git safety policy"
    } else {
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

foreach ($CommandName in @("git", "codex", "python", "Rscript", "xelatex", "quarto")) {
    $Available = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($Available) { Write-Host "INFO  tool available: $CommandName" }
    elseif ($CommandName -eq "git" -or $CommandName -eq "codex") {
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
