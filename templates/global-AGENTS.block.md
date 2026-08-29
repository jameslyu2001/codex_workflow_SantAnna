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

## Default research-file organization

- Unless the nearest project `AGENTS.md` overrides it, organize academic data work as the stage pipeline `raw -> derived -> analysis` across matching `data/`, `source/`, and `output/` trees.
- Put original data-like inputs in `data/raw/`; intermediate data in `data/derived/`; and complete, analysis-ready data in `data/analysis/`. Never modify raw inputs in place.
- Put code that processes each stage in `source/raw/`, `source/derived/`, or `source/analysis/`. Put figures, tables, logs, and other non-data products in the matching `output/<stage>/` directory, classified by their input stage.
- Keep corresponding subject or dataset subpaths aligned across `data/<stage>/`, `source/<stage>/`, and `output/<stage>/` where practical so provenance is visible from the path.
- Use `temp/` only for disposable intermediates. Store proposals, related papers, ideas, manuscripts, and editable AI-generated drafts under an appropriate `documents/` subfolder; default AI-generated prose to English unless the user requests otherwise.
- Track `source/` and repository-maintenance code in Git. Treat versioning of `data/`, `output/`, and `temp/` as a project-specific decision based on privacy, licenses, size, and reproducibility requirements.
- Inspect existing conventions before reorganizing a repository, preserve unrelated files, and do not mass-move existing content without an explicit request.
<!-- END academic-workflow -->
