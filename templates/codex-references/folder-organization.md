# Default academic project file organization

Use this convention when creating, moving, or saving research files in an academic project, unless the nearest repository `AGENTS.md` defines a different structure. Inspect an existing repository before reorganizing it; do not mass-move existing files without an explicit request.

## Canonical structure

```text
data/
  raw/
  derived/
  analysis/
source/
  raw/
  derived/
  analysis/
output/
  raw/
  derived/
  analysis/
temp/
documents/
scripts/
```

`data/`, `source/`, and `output/` use the same stage names and, where practical, the same subject or dataset subpaths. For example, work on `data/raw/survey/wave1/` should use corresponding locations under `source/raw/survey/wave1/` and `output/raw/survey/wave1/`. This makes provenance visible from the path alone.

## Routing rules

| Input stage | Processing or analysis code | Data-like result | Figure, table, log, or other non-data result |
|---|---|---|---|
| External/original material | `source/raw/` | Original inputs stay in `data/raw/`; converted, extracted, cleaned, or otherwise processed data go to `data/derived/` | `output/raw/` |
| `data/derived/` | `source/derived/` | Analysis-ready data go to `data/analysis/` | `output/derived/` |
| `data/analysis/` | `source/analysis/` | `data/analysis/` only when a further data artifact is genuinely required | `output/analysis/` |

Apply these definitions consistently:

- `data/raw/` contains original inputs of any data-like type, including PDFs, spreadsheets, Stata files, JSON, images used as data, and downloaded source files. Do not modify raw files in place.
- `data/derived/` contains intermediate data produced from raw inputs.
- `data/analysis/` contains the complete, analysis-ready final datasets. Treat it as a terminal data stage by default.
- `source/<stage>/` contains code whose inputs belong to that stage. A script that reads both raw and derived data belongs to the earliest stage it materially transforms, unless the project `AGENTS.md` specifies another rule.
- `output/<stage>/` contains non-data products generated while working from that stage, including figures, tables, reports, diagnostics, and logs. Classify by the input stage, not by the file extension.
- `temp/` contains disposable intermediates only. No canonical input, result, citation target, or handoff artifact may exist only in `temp/`.
- `documents/` contains proposals, related papers, research ideas, manuscripts, and other prose. Put AI-generated drafts in an appropriate subfolder here, normally in English and preferably as `.tex` or another editable source format unless the user requests a different language or format.
- `scripts/` is reserved for repository infrastructure such as builds, validation, compilation, deployment, and workflow helpers. Data transformation and empirical analysis code belongs under `source/<stage>/`.

## Version control and project overrides

- Track `source/` and repository-maintenance code under `scripts/` in Git.
- Do not infer that `data/`, `output/`, or `temp/` should be committed. Their Git policy depends on privacy, licenses, file size, reproducibility requirements, and the repository's own `AGENTS.md` or `.gitignore`.
- Preserve existing project conventions when adoption would require disruptive relocation. Record any intentional deviation or migration plan in the repository `AGENTS.md`.
- Keep absolute machine paths, named datasets, retention rules, and project-specific exceptions in the repository `AGENTS.md`, not in global guidance.
