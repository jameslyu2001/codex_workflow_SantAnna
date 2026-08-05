---
name: academic-workflow-commit
description: "Prepare and create an intentional Git commit for completed academic workflow changes. Use when the user asks to commit current work, after verifying scope, repository status, and relevant checks. Does not push unless separately requested."
---

# Create an intentional commit

1. Confirm the user requested a commit and identify the repository root.
2. Inspect `git status`, relevant diffs, and recent commit style. Preserve unrelated user changes.
3. Run checks proportionate to the changed artifacts. For generated papers, slides, analyses, or documentation, verify the actual output when practical.
4. Stage an explicit file set. Do not use `git add -A` or stage secrets, local settings, caches, session logs, or unrelated changes.
5. Review the staged diff and summarize exactly what will be committed.
6. Create one focused commit with a concise message that explains the outcome.
7. Report the commit hash and any changes deliberately left unstaged.

Do not add generated-by footers, amend an existing commit, force-push, or push unless the user explicitly requests that separate action.
