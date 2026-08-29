# Codex academic workflow quick reference

## Core loop

1. Resolve the requested deliverable, evidence, constraints, assumptions, and verification criteria.
2. Inspect the real project and its nearest `AGENTS.md` before changing files.
3. Implement the smallest complete change while preserving unrelated work.
4. Run proportionate mechanical and substantive checks.
5. Use a focused `academic_*` reviewer or a review skill when independent judgment is warranted.
6. Fix confirmed critical and major findings, rerun checks, and report unresolved limits.

## Durable scope

| Information | Codex location |
|---|---|
| Personal defaults across repositories | `~/.codex/AGENTS.md` |
| Reusable academic procedures | `~/.agents/skills/academic-workflow-*` |
| Specialist reviewer roles | `~/.codex/agents/academic_*.toml` |
| Global lifecycle bookkeeping | `~/.codex/hooks.json` and `~/.codex/hooks/academic-workflow/` |
| Command safety policy | `~/.codex/rules/academic-workflow.rules` |
| Project paths, commands, notation, thresholds | repository `AGENTS.md` |
| Verified project knowledge | repository `MEMORY.md` and project documentation |
| Personal reusable lessons | `~/.codex/academic-workflow-state/personal-memory.md` |

## Default research-file pipeline

Use matching `raw`, `derived`, and `analysis` stages across `data/`, `source/`, and `output/`. Keep original inputs in `data/raw/`, intermediate data in `data/derived/`, analysis-ready data in `data/analysis/`, stage-specific code in `source/<stage>/`, and non-data products in `output/<stage>/`. Use `temp/` only for disposable files and `documents/` for research prose. See `references/codex/folder-organization.md` for the routing table and exceptions.

## Project opt-in

Run `$academic-workflow-init` once in an academic repository. It creates `.codex/academic-workflow.json`; stateful global hooks no-op when that marker is absent.

## Codex-native substitutions

- Invoke a workflow with `$academic-workflow-<name>`; Codex can also select a matching skill implicitly.
- Use custom `academic_*` agents for bounded specialist review.
- Use native `/statusline` for model, context, branch, and directory information.
- Use native desktop/TUI notification settings; do not install the upstream notification shell hook.
- Use `codex resume --last` for the most recent interactive task in the current working directory.
- Use `codex mcp add` for MCP registration.
- Review and trust installed lifecycle hooks with `/hooks` after installation or hook changes.

## Completion gate

Do not describe a paper, analysis, replication, or slide deck as complete until required artifacts exist, numerical claims trace to evidence, relevant code or builds pass, and visual or substantive review is complete in proportion to risk.
