---
name: academic-workflow-extract-tikz
description: "Extract TikZ diagrams from a Beamer source, validate them, compile a standalone verification document, and review visual quality. Use when the user asks to extract lecture diagrams."
---

# Extract TikZ diagrams

1. Resolve the Beamer `.tex` source from the user prompt and require a unique match under `Slides/` when no explicit path is given.
2. Read the source and identify complete diagram units, including required TikZ libraries, colors, macros, and surrounding definitions. Do not copy only the inner `tikzpicture` when it depends on local definitions.
3. Create or update `Figures/<lecture>/extract_tikz.tex` as a standalone XeLaTeX document. Preserve unrelated diagrams already present.
4. Validate the extracted file:

   ```powershell
   python ".\scripts\check-tikz-prevention.py" ".\Figures\<lecture>\extract_tikz.tex"
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\compile-latex.ps1" -Target ".\Figures\<lecture>\extract_tikz.tex"
   ```

   Substitute the actual lecture name before running commands.
5. Render and visually inspect the result. When available, ask `academic_tikz_reviewer` for a focused review and iterate on confirmed overlap, clipping, label, or consistency problems.
6. Report the extracted diagrams, validation result, PDF path, and unresolved visual issues. Synchronize to `docs/` only if requested.
