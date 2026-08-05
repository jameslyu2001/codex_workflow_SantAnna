---
name: academic-workflow-new-skill
description: "Create a reusable Codex skill from a repeated academic or technical workflow. Use when the user asks to write, scaffold, or turn a recurring process into a skill. Default to a personal global skill unless the workflow is explicitly project-specific."
---

# Create a Codex skill

Use the current system `$skill-creator` workflow rather than reproducing its schema from memory.

1. Resolve concrete trigger examples, expected outputs, required tools, and verification criteria.
2. Choose scope:
   - default to `$HOME/.agents/skills/<skill-name>` for a workflow useful across repositories;
   - use `<repo>/.agents/skills/<skill-name>` only when the workflow depends on that repository or the user requests team scope.
3. Search existing user and project skills for overlap. Update an existing skill when its trigger and outcome already match.
4. Use a lowercase kebab-case name under 64 characters. The folder name must equal the frontmatter `name`.
5. Keep only `name` and `description` in `SKILL.md` frontmatter. Put what the skill does and when it triggers in the description.
6. Keep the body concise and imperative. Put deterministic helpers in `scripts/`, detailed knowledge in `references/`, and output resources in `assets/`.
7. Generate `agents/openai.yaml` when appropriate, following the current `$skill-creator` reference rather than inventing fields.
8. Run the official `quick_validate.py` and execute representative scripts. On Windows, force Python UTF-8 if the console locale would otherwise misread the Markdown.
9. Report the installed path, validation result, and one example invocation. Restart Codex only if automatic discovery does not refresh.

Do not create Claude-specific frontmatter such as `allowed-tools`, `argument-hint`, or `disable-model-invocation`.
