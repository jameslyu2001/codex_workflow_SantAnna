---
name: academic-workflow-context-status
description: "Report the current Codex task's durable working state, active plan, Git status, recent workflow logs, unresolved blockers, and handoff readiness. Use when the user asks for context status, session health, or whether work can safely continue in a new task."
---

# Report task and handoff status

Do not invent a context-window percentage. If the active Codex surface does not expose exact token usage, say that it is unavailable.

1. Summarize the current objective and latest user constraints from the task.
2. Read the active plan through the available planning or goal interface when present.
3. Inspect the current repository's branch and working-tree status without modifying it.
4. Locate the newest relevant files under `quality_reports/plans/`, `quality_reports/checkpoints/`, and `quality_reports/session_logs/` when those directories exist.
5. Report completed work, unverified work, unresolved questions, blockers, modified files, and the next one to three actions.
6. Check whether essential decisions and file pointers are stored on disk. If not, recommend `$academic-workflow-checkpoint` or `$academic-workflow-compress-session`.

Separate verified state from inference. A concise handoff is more useful than a speculative context estimate.
