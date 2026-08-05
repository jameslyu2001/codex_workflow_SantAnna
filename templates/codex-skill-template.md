# Codex skill template

Use the current system `$skill-creator` skill before creating or updating a skill. This template is a compact starting point; the system skill is authoritative if requirements change.

## Location

- Personal global skill: `$HOME/.agents/skills/<skill-name>/SKILL.md`
- Repository skill: `<repo>/.agents/skills/<skill-name>/SKILL.md`

Default to personal global scope for workflows that apply across repositories. Use repository scope only for project-specific knowledge or team workflows.

## `SKILL.md`

```markdown
---
name: descriptive-kebab-case-name
description: "Describe what the skill does and the concrete situations that should trigger it."
---

# Skill title

1. Inspect the relevant inputs and constraints.
2. Execute the reusable workflow.
3. Verify the result with a deterministic check when possible.
4. Report outputs, evidence, and unresolved limitations.
```

Keep only `name` and `description` in frontmatter. Use lowercase letters, digits, and hyphens for the name, keep it under 64 characters, and make the folder name match.

Put deterministic helpers in `scripts/`, detailed knowledge in `references/`, and output resources in `assets/`. Add `agents/openai.yaml` when UI metadata is useful, following the current `$skill-creator` reference.

Validate with the official `$skill-creator` `quick_validate.py` and run representative scripts before declaring the skill ready.
