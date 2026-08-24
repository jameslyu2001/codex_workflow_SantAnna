# Claude → Codex migration map

| Upstream component | Codex destination | Treatment |
|---|---|---|
| Root `CLAUDE.md` | Global marked `~/.codex/AGENTS.md` block plus project `AGENTS.md` | Generic behavior is global; project paths, commands and thresholds remain local |
| User research-folder convention | Global marked `~/.codex/AGENTS.md` block, core reference, and non-overwriting project scaffold | The reusable `raw -> derived -> analysis` routing is global; absolute paths, datasets, retention rules, and exceptions remain project-local |
| 52 `.claude/skills/*` | `~/.agents/skills/academic-workflow-*` | Namespaced, frontmatter reduced to Codex fields, arguments/tools/CLI/path references rewritten |
| 18 `.claude/agents/*.md` | `~/.codex/agents/academic_*.toml` | Converted to Codex custom-agent TOML with role-appropriate sandbox modes |
| 32 `.claude/rules/*.md` | `academic-workflow-core/references/rules/` | On-demand global methodological references; not execpolicy files |
| 9 `.claude/references/*` | `academic-workflow-core/references/upstream/` | On-demand global references with Codex paths and agent names |
| 2 `.claude/output-styles/*` | `$academic-workflow-style-academic-writing` and `$academic-workflow-style-referee` | Reimplemented as discoverable global Codex skills |
| Git guardrail hook | `~/.codex/rules/academic-workflow.rules` plus Codex `PreToolUse` hook | Native command policy is primary; hook covers Git global options and academic hardcoded-path warnings |
| Claim reconciliation hook | Codex `PostToolUse` hook | Parses `apply_patch` input and alerts only in initialized projects |
| Pre-compact capture | Codex `PreCompact` hook | Stores plan/session state under `~/.codex/academic-workflow-state/sessions` |
| Post-compact restore | Codex `SessionStart` hook for `compact|resume` | Injects active plan and session-log context after compaction/resume |
| Session log hook | Codex `Stop` hook | Writes only in projects containing `.codex/academic-workflow.json` |
| Context percentage hook | Native `context-remaining` status-line item and actual `PreCompact` event | Approximate Claude transcript-size percentages deliberately removed |
| Claude `statusLine` shell script | Codex `tui.status_line` / `/statusline` | Uses native model, context, branch and directory fields |
| Claude Notification hook | Codex Desktop/TUI notifications and existing `notify` config | Existing user notification command is preserved |
| Claude permission allow-all settings | None | Deliberately rejected; Codex sandbox and approvals remain active |
| Fixed Claude model routing | Codex role-based custom agents | Inherits the configured Codex model unless the user deliberately overrides it |
| Root `scripts/` | Selected missing files installed per project | R templates, TikZ checks, quality scoring, Windows PowerShell and macOS Bash compile/deploy scripts; Claude self-maintenance scripts excluded |
| `quality_reports`, `explorations` | Created by `$academic-workflow-init` | Project evidence and provisional work remain project-local |
| `.github`, `.githooks`, `.vscode` | `$academic-workflow-init -IncludeAutomation` | Opt-in because these files can change CI, commits, and editor behavior |
| `MEMORY.md` | Project `MEMORY.md` template | Verified project facts only; personal reusable lessons remain global state |

## Invocation and command substitutions

| Claude form | Codex form |
|---|---|
| `/skill-name` | `$academic-workflow-skill-name` |
| `$ARGUMENTS` | `<user-input>` documentation placeholder; substitute the actual prompt value before execution |
| `claude --continue` | `codex resume --last` |
| `claude -p` | `codex exec` |
| `claude mcp add` | `codex mcp add` |
| `Task`/fixed model names | Bounded Codex subagent using an `academic_*` role |
| `Glob`, `Grep`, `Read`, `Write`, `Edit`, `Bash`, `Monitor` | Current Codex file, shell, search, background-process, wait, and edit tools |
| `$CLAUDE_PROJECT_DIR` | Current Git repository root or hook input `cwd` |
| Claude env flags | `CODEX_ACADEMIC_*` opt-in environment flags |

## Platform entry points

| Platform | One-click installer | Verification | Project initializer |
|---|---|---|---|
| Windows | `install.ps1` | `verify-install.ps1` | `init-project.ps1` |
| macOS | `install-macos.sh` → `scripts/install_macos.py` | `verify-install-macos.sh` | `init-project.py` |

Both platforms install the same 56 skills, 18 custom agents, five hook groups, global guidance, rules, and personal state. Only OS-facing commands and project scripts differ.

## Scope rule

Reusable procedures, agents, hook code, references, safety policy, and the default research-file routing convention are global. Absolute data locations, named datasets, real build commands, notation, retention policy, project exceptions, CI, Git hooks, and generated evidence are project-local. This split follows Codex's global/user and repository instruction layers rather than reproducing the upstream template folder verbatim.
