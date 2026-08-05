---
name: academic-workflow-compile-latex
description: "Compile and verify a Beamer or LaTeX document on Windows with XeLaTeX, optional BibTeX, repeated passes, log checks, and output inspection. Use when the user asks to compile slides or a .tex document."
---

# Compile LaTeX with XeLaTeX

1. Resolve the target from the user prompt. Prefer an explicit `.tex` path; otherwise look under `Slides/` and require a unique match.
2. Preserve existing sources and confirm `xelatex` is available. If `scripts/compile-latex.ps1` is absent, run `$academic-workflow-init` or explain the missing project scaffold.
3. From the repository root, run:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\compile-latex.ps1" -Target "<actual-target>"
   ```

   Substitute the real target before executing. The script runs three XeLaTeX passes and runs BibTeX only when the auxiliary file declares bibliography data.
4. Inspect the `.log` for undefined references, missing citations, fatal errors, and meaningful overfull boxes. Do not call compilation successful merely because a PDF exists.
5. Inspect the generated PDF visually when the environment supports PDF rendering. For a changed lecture, use `academic_slide_auditor` or `$academic-workflow-visual-audit` when layout risk warrants it.
6. Report the PDF path, passes completed, warnings that remain, and any unavailable dependency.

Do not silently switch to pdfLaTeX, delete unrelated auxiliary files, or open GUI applications unless the user asks.
