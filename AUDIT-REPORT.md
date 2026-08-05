# Codex workflow parity audit

Audit date: 2026-08-05

Upstream repository: `pedrohcgs/claude-code-my-workflow`

Audited upstream commit: `be53c12f235996dff41fb7f21580506fd2dd8d50`

## Findings before version 2.0.0

| Severity | Finding | Evidence | Impact | Resolution |
|---|---|---|---|---|
| Major | No upstream hooks were installed, although current Codex supports the required lifecycle events | Upstream: 7 files under `.claude/hooks`; installed: no `~/.codex/hooks.json` | Lost Git/path guardrails, stale-claim reminders, compaction state, and session logging | Added five native Codex hook groups and six Python files; stateful hooks require a project marker |
| Major | `$ARGUMENTS` was replaced by a prose sentence in 49 locations across 22 installed skills | Installed commands such as `xelatex ... the arguments and context supplied by the user.tex` | Exact commands and filenames were invalid | Converter now uses `<user-input>` and explicitly requires substitution before execution |
| Major | Initializer created an empty `scripts/`, although installed skills call root scripts | Deploy, TikZ and analysis skills reference `scripts/sync_to_docs.sh`, `check-tikz-prevention.py`, and `scripts/R/*` | Fresh projects could not execute advertised workflows | Initializer now merges required cross-platform/upstream scripts and Windows-native compile/deploy scripts without overwriting files |
| Major | Project evidence structure was incomplete | `quality_reports/` and `explorations/` were created only as empty top-level folders | Hooks and skills expected missing plans, passports, logs and archives | Initializer creates the complete evidence subdirectory set and opt-in marker |
| Major | Active Claude CLI and tool assumptions remained | `claude --continue`, `claude mcp add`, headless `claude -p`, `Monitor tool`, fixed Claude model strings | Instructions could fail or route work incorrectly in Codex | Added Codex CLI/tool/model conversion and targeted Windows skill overrides |
| Major | LaTeX and deploy instructions were macOS/Linux-oriented | POSIX environment prefixes, `.sh` calls, `open`/`xdg-open` | Commands did not work in Windows PowerShell | Added `compile-latex.ps1`, `sync-to-docs.ps1`, and four Windows-aware skill overrides |
| Moderate | Two upstream output styles had no Codex equivalent | `.claude/output-styles/academic-writing.md`, `referee.md` | Style behavior was unavailable for explicit or implicit reuse | Added two global Codex style skills |
| Moderate | Upstream quick-reference behavior was not discoverable in the installed core | `.claude/WORKFLOW_QUICK_REF.md` absent from installed core | Users could not see the Codex surface mapping and completion gate | Added a Codex-native quick reference under the core skill's references |
| Moderate | Native Codex status-line capability was unused | No `tui.status_line`; upstream used a Claude shell status line | CLI lacked branch/context parity | Installer adds native fields only when the user has no existing `status_line` |
| Moderate | Execpolicy covered only part of the upstream Git guardrail set | No native rules for `git add .`, `git add --all`, `git clean -fdx`, mass checkout/restore | Some dangerous or convention-breaking commands were not policy-gated | Expanded `.rules`; PreToolUse hook covers `git -C` and `git -c` forms |

## Deliberate non-ports

- Claude's `bypassPermissions` is not copied. Codex sandboxing and approvals remain authoritative.
- The approximate context-percentage hook is not copied. It assumed a Claude context window and estimated tokens from transcript bytes; Codex's native `context-remaining` field and real `PreCompact` event are more reliable.
- The upstream notification shell script is not copied. Codex Desktop/TUI notification settings and any existing `notify` command are preserved.
- Upstream self-maintenance scripts that validate Claude surfaces, model versions, or the original repository's website are not installed into ordinary academic projects.
- Project CI, Git hooks and VS Code settings are opt-in through `-IncludeAutomation`; installing them silently would exceed global workflow scope.
- Upstream project facts and historical `MEMORY.md` entries are not made global. A clean project-memory template is used instead.

## Verification criteria

Version 2.0.0 is release-ready only when all of the following pass:

- PowerShell and Python syntax checks
- 56 skill folder/frontmatter checks and official skill validation
- 18 custom-agent TOML checks with valid sandbox modes
- zero active Claude CLI, invalid argument-phrase, or `.claude` path residues in installed skills/agents
- Codex hook JSON merge, six hook-script parses, and synthetic behavior tests
- execpolicy inline and representative command tests
- disposable-project initialization, preservation, and idempotence tests
- full local install followed by `verify-install.ps1`
- E-drive package hash parity and GitHub remote commit parity

The release verification section should be read together with the actual command output from the release process; missing optional academic software is not reported as successful functionality.
