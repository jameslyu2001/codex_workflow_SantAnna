---
name: academic-workflow-permission-check
description: "Diagnose why Codex prompts for approval, blocks a command, or cannot access a file or network resource. Use for permission prompts, sandbox denials, rule conflicts, trusted-project configuration, or differing behavior between Codex surfaces. Read-only unless the user separately asks for a change."
---

# Diagnose Codex permissions

Keep this diagnostic read-only. Never weaken a sandbox, approval policy, managed requirement, or command rule unless the user separately requests that change.

1. Record the current Codex surface, `codex --version`, working directory, requested operation, and exact denial or approval message.
2. Distinguish the four controls that are often confused:
   - filesystem and network sandbox permissions;
   - approval policy for leaving the sandbox;
   - command rules under an active `rules/` directory;
   - managed or administrator requirements that local settings cannot override.
3. Inspect the narrowest relevant layers in precedence order:
   - current-session permission profile exposed by the active Codex surface;
   - project `.codex/config.toml` and project `.codex/rules/` when the repository is trusted;
   - user `~/.codex/config.toml` and `~/.codex/rules/`;
   - managed configuration only when present and readable.
4. Read only relevant keys. Do not print tokens, environment secrets, unrelated MCP credentials, or full configuration files.
5. For a command-rule question, run `codex execpolicy check --pretty --rules <rule-file> <command tokens>` against the exact command.
6. Identify the winning restriction. A more permissive local value cannot override a stricter runtime, managed, or sandbox boundary.
7. Recommend the smallest safe remedy: use an already writable path, request scoped access, correct a malformed rule, trust the intended project, or start a new Codex task after configuration changes.

Report the evidence, winning layer, diagnosis, and recommended action. If the active app supplies a permission profile that differs from disk configuration, treat the verified runtime profile as authoritative for that task.
