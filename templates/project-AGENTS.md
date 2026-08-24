# Academic project instructions

## Project identity

- Project: `[replace with project name]`
- Research question: `[replace with the primary question]`
- Primary outputs: `[paper / slides / analysis / replication package]`
- Canonical source files: `[list authoritative files]`

## Repository conventions

- Treat this repository as the source of truth for project-specific notation, paths, build commands, and quality thresholds.
- Put exploratory work under `explorations/` and durable review evidence under `quality_reports/`.
- Preserve source-to-output provenance for every reported numerical result.
- Never edit raw data in place. Write cleaned and derived data to documented output locations.
- Keep generated files out of source directories unless this repository explicitly tracks them.
- Use the default `raw -> derived -> analysis` organization below unless this project documents an explicit exception.
- Treat `.codex/academic-workflow.json` as the opt-in marker for the global academic hooks. Do not remove it unless this repository should leave the workflow.

## Working structure

- `data/raw/`: immutable original inputs of any data-like type.
- `data/derived/`: intermediate data produced from raw inputs.
- `data/analysis/`: complete, analysis-ready final datasets; additional data artifacts stay here only when genuinely required.
- `source/raw/`, `source/derived/`, `source/analysis/`: transformation or analysis code, classified by the stage of its inputs.
- `output/raw/`, `output/derived/`, `output/analysis/`: figures, tables, logs, reports, and other non-data products, classified by the stage of their inputs.
- Keep subject or dataset subpaths aligned across the corresponding `data/`, `source/`, and `output/` stage directories where practical.
- `temp/`: disposable intermediates only; no canonical artifact may exist only here.
- `documents/`: proposals, related papers, research ideas, manuscripts, and editable AI-generated drafts. Default AI-generated prose to English unless the user requests otherwise.
- `scripts/`: repository infrastructure such as validation, compilation, deployment, and workflow helpers; data-processing code belongs under `source/`.
- `quality_reports/`: plans, audits, checkpoints, diagnostics, preregistrations, claim passports, and session evidence.
- `explorations/`: explicitly provisional work that is not yet a production result.
- `MEMORY.md`: verified project facts and decisions; personal or machine-specific lessons do not belong here.
- `master_supporting_docs/`: source papers or slides used as inputs, subject to repository data and copyright policy.

Track `source/` and repository-maintenance code under `scripts/` in Git. Document whether `data/` and `output/` are tracked, externalized, or ignored; never commit restricted or licensed material without authorization.

## Verification

- Run the narrowest relevant checks after each meaningful change.
- Before handoff, compile or render changed documents and inspect the produced artifact when tooling is available.
- For empirical work, rerun affected scripts and reconcile manuscript/table/figure claims against their generated outputs.
- Surface missing dependencies, unavailable data, and unverified claims explicitly.

## Project commands

Fill these in after initialization:

```text
Environment check: [command]
Paper build:       [command]
Slides build:      [command]
Analysis:          [command]
Tests/checks:      [command]
```

Remove commands that do not apply. Add the real working directory, required environment, expected outputs, and success criteria for each retained command.
