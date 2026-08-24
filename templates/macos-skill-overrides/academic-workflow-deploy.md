---
name: academic-workflow-deploy
description: "Render Quarto materials and synchronize verified HTML, PDFs, code, and figures into docs/ on macOS. Use when the user asks to deploy or prepare GitHub Pages outputs."
---

# Render and synchronize teaching materials

1. Resolve whether the user named one lecture or requested all lectures. Confirm `quarto` is available and inspect the repository's deployment conventions.
2. If `scripts/sync-to-docs.sh` is absent, run `$academic-workflow-init` or report that the project scaffold is missing.
3. Run one of:

   ```bash
   bash ./scripts/sync-to-docs.sh
   bash ./scripts/sync-to-docs.sh "<actual-lecture>"
   ```

4. Verify the rendered HTML and copied assets under `docs/`; inspect at least the changed page and confirm referenced `_files` assets exist.
5. Run repository-specific checks when present. Report render failures and missing optional inputs honestly.
6. Do not commit, push, change GitHub Pages settings, or publish externally unless explicitly requested.
