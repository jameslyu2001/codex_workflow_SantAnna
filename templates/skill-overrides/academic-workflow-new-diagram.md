---
name: academic-workflow-new-diagram
description: "Create a new TikZ diagram from the installed academic template gallery, compile it, and iterate through visual review. Use when the user asks for a new causal, economic, timeline, or flow diagram."
---

# Create a TikZ diagram

1. Resolve the intended diagram, labels, destination, and source lecture from the user prompt. Inspect existing project colors and notation before choosing a template.
2. Select the closest scaffold under `templates/tikz-snippets/` and copy it to a specific file under `Figures/<topic>/`. Preserve the template itself.
3. Adapt nodes, edges, labels, colors, and dimensions to the project's conventions. Keep information hierarchy clear and avoid decorative complexity.
4. Run:

   ```powershell
   python ".\scripts\check-tikz-prevention.py" ".\Figures\<topic>\<diagram>.tex"
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\compile-latex.ps1" -Target ".\Figures\<topic>\<diagram>.tex"
   ```

   Substitute actual paths before executing.
5. Inspect the rendered result and ask `academic_tikz_reviewer` for a focused visual review when available. Fix confirmed clipping, overlap, spacing, and consistency issues, then recompile.
6. Report the source path, rendered artifact, checks run, and any remaining limitations.
