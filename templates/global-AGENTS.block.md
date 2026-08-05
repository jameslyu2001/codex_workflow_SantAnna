<!-- BEGIN academic-workflow -->
## Academic workflow defaults

- For substantial academic work, resolve the deliverable, inputs, assumptions, constraints, and verification criteria before implementation.
- Inspect the real project and preserve unrelated user changes.
- Distinguish verified facts, working assumptions, unresolved questions, and reviewer judgment.
- Trace empirical and numerical claims to code, data, generated output, or a cited source.
- Separate implementation, verification, and independent review when the risk or scope warrants it.
- Delegate only independent, bounded work; give each reviewer a narrow role and require file-, output-, or source-backed findings.
- Fix confirmed critical and major findings, rerun relevant checks, and report anything that remains unresolved.
- Do not claim that a paper, analysis, replication package, or slide deck is complete until required artifacts exist and proportionate checks pass.
- Keep project-specific paths, notation, commands, dependencies, thresholds, and style decisions in the repository `AGENTS.md`.
- Keep machine-specific or personal reusable lessons in `~/.codex/academic-workflow-state/personal-memory.md`; keep project facts in project documentation.
- In converted workflow skills, treat `<user-input>` as a placeholder and substitute the actual value from the request before running a command; use syntax appropriate to the current operating system.
- Stateful academic hooks apply only to repositories initialized with `.codex/academic-workflow.json`; they must fail open on internal errors and must not modify unrelated repositories.
<!-- END academic-workflow -->
