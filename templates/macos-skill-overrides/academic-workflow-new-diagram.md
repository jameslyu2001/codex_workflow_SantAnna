---
name: academic-workflow-new-diagram
description: "Create a new TikZ diagram on macOS from the installed academic template gallery, compile it, and iterate through visual review."
---

# Create a TikZ diagram

1. Resolve the intended diagram, labels, destination, and source lecture. Inspect existing project colors and notation.
2. Select the closest scaffold under `templates/tikz-snippets/` and copy it to a specific file under `Figures/<topic>/`. Preserve the template.
3. Adapt nodes, edges, labels, colors, and dimensions to project conventions.
4. Validate and compile:

   ```bash
   python3 ./scripts/check-tikz-prevention.py "./Figures/<topic>/<diagram>.tex"
   bash ./scripts/compile-latex.sh "./Figures/<topic>/<diagram>.tex"
   ```

5. Substitute actual paths, inspect the result, and ask `academic_tikz_reviewer` for a focused visual review when available. Fix confirmed issues and recompile.
6. Report the source, rendered artifact, checks, and remaining limitations.
