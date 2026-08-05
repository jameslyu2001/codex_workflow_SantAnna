---
name: academic-workflow-deep-audit
description: "Audit the installed Codex academic workflow or a project's workflow integration for broken skills, agents, rules, references, encodings, stale Claude-specific assumptions, and failed initialization. Use after broad workflow changes, before distribution, or when the user asks to check everything."
---

# Deep audit the Codex academic workflow

Audit before repairing. Make fixes only when the user requested remediation as well as diagnosis, and preserve unrelated user files.

## Mechanical checks

1. Locate the installation manifest at `~/.codex/academic-workflow-install.json` and the vendor source it identifies.
2. Confirm the marked academic block exists exactly once in `~/.codex/AGENTS.md` unless installation intentionally skipped it.
3. Enumerate `~/.agents/skills/academic-workflow-*`. For every skill:
   - require a `SKILL.md` whose folder and frontmatter names match;
   - require only `name` and `description` in frontmatter;
   - run the current `$skill-creator` `quick_validate.py` when its dependencies are available;
   - check local links and referenced scripts or assets;
   - reject UTF-8 corruption and active `.claude` paths or Claude-only tool instructions.
4. Parse every `~/.codex/agents/academic_*.toml`. Require `name`, `description`, and `developer_instructions`; verify any `sandbox_mode` matches the role's need.
5. Validate `~/.codex/rules/academic-workflow.rules` with `codex execpolicy check` using every inline example plus representative safe commands.
6. Parse `academic-workflow-init/scripts/init-project.ps1` with the Windows PowerShell parser and run it against a disposable workspace project. Verify it preserves existing files.
7. Compare source and installed skill and agent counts. Explain intentional Codex-only additions or overrides.

## Behavioral checks

- Sample at least one paper review, empirical analysis, slide, literature, and project-initialization skill.
- Confirm specialist references name discoverable `academic_*` custom agents.
- Confirm optional dependencies are reported honestly rather than treated as completed work.
- Confirm dangerous Git operations remain blocked or approval-gated.
- Confirm project facts stay in project `AGENTS.md`, while personal reusable lessons use `~/.codex/academic-workflow-state/personal-memory.md`.

Report each finding with severity, evidence path, impact, and verification. Repeat mechanical checks after repairs and stop when a full round finds no new genuine issue.
