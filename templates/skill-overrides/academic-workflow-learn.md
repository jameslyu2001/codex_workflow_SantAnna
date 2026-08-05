---
name: academic-workflow-learn
description: "Capture a verified, non-obvious discovery as a reusable Codex skill or update to an existing skill. Use after costly debugging, a reliable workaround, an undocumented integration, or a repeated multi-step workflow."
---

# Turn a discovery into reusable Codex knowledge

1. State the non-obvious lesson, evidence that it is correct, exact trigger conditions, reusable solution, and verification method.
2. Continue only if the lesson is verified and likely to recur. Do not encode a one-off fact, an untested hypothesis, a secret, or project data into a global skill.
3. Search `$HOME/.agents/skills` and the current repository's `.agents/skills` for overlapping triggers.
4. Update an existing skill when possible. Otherwise invoke the current `$skill-creator` workflow.
5. Default to a user-global skill for tool behavior or reusable methods. Use a repository skill or the nearest `AGENTS.md` for project-specific conventions and facts.
6. Include the problem, triggers, solution, verification, one concrete example, and authoritative references. Keep detailed material in `references/` when it would bloat `SKILL.md`.
7. Run the official skill validator and exercise any added script on a safe representative case.
8. Report what was created or updated, why its scope is correct, and how future Codex tasks should invoke it.

For a personal lesson that is useful but not yet mature enough to become a skill, append a short evidence-backed candidate to `~/.codex/academic-workflow-state/personal-memory.md` instead.
