---
name: academic-workflow-extract-tikz
description: "Extract TikZ diagrams from a Beamer source on macOS, validate them, compile a standalone verification document, and review visual quality."
---

# Extract TikZ diagrams

1. Resolve the Beamer `.tex` source from the prompt and require a unique match under `Slides/` when no explicit path is given.
2. Identify complete diagram units, including required libraries, colors, macros, and surrounding definitions.
3. Create or update `Figures/<lecture>/extract_tikz.tex` as a standalone XeLaTeX document. Preserve unrelated diagrams.
4. Validate and compile:

   ```bash
   python3 ./scripts/check-tikz-prevention.py "./Figures/<lecture>/extract_tikz.tex"
   bash ./scripts/compile-latex.sh "./Figures/<lecture>/extract_tikz.tex"
   ```

5. Substitute actual paths, visually inspect the result, and ask `academic_tikz_reviewer` for focused review when available.
6. Report extracted diagrams, validation, PDF path, and unresolved visual issues. Synchronize to `docs/` only if requested.
