# Migration map

| Upstream component | Codex destination | Treatment |
|---|---|---|
| Root `CLAUDE.md` | Global marked `AGENTS.md` block plus project `AGENTS.md` | Split generic behavior from project facts |
| `.claude/skills/*` | `$HOME/.agents/skills/academic-workflow-*` | Global, namespaced, frontmatter and invocations rewritten |
| `.claude/agents/*.md` | `~/.codex/agents/academic_*.toml` | Global TOML custom agents |
| `.claude/rules/*.md` | `academic-workflow-core/references/rules/` | Global on-demand prose references |
| `.claude/references/*` | `academic-workflow-core/references/upstream/` | Global on-demand references |
| Git guardrail hook | `~/.codex/rules/academic-workflow.rules` | Reimplemented as native Codex command policy |
| Permission allow-all configuration | None | Deliberately rejected |
| Context/status/notification hooks | None | Claude-specific; use Codex-native session and notification behavior |
| `Preambles`, `templates`, `scripts` | Per-project, installed by `$academic-workflow-init` | Depend on repository contents |
| `.githooks`, `.github` | Per-project | Version-control and CI enforcement |
| `MEMORY.md`, project knowledge base | Per-project | Contains project-specific learning and decisions |
| `quality_reports`, `explorations` | Per-project | Durable project outputs |

## Behavioral substitutions

| Claude behavior | Codex behavior |
|---|---|
| `/skill-name` | `$academic-workflow-skill-name` |
| `Task` with `context: fork` | Spawn an isolated Codex subagent with a narrow task |
| `.claude/settings.json` permissions | Codex sandbox, approval policy, permission profiles, and `.rules` |
| `CLAUDE_PROJECT_DIR` | Resolve the current Git root or workspace directory |
| Fixed Claude model routing | Role-based Codex agents; inherit the user's configured model unless a deliberate override is needed |
| PreCompact memory script | Codex session persistence/compaction plus durable project reports |
