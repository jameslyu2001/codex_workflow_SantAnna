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
