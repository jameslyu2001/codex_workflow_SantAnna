---
name: academic-workflow-compress-session
description: "Distill a long Codex task into a durable handoff note containing decisions, evidence, file pointers, open questions, discarded hypotheses, and the next one to three actions. Use before changing tasks, handing work to another agent, or when accumulated context is becoming noisy."
---

# Distill the current task

1. Use the current conversation, active plan, Git status, and recent project logs as sources. Do not claim access to hidden context metrics.
2. Create `quality_reports/session_logs/YYYY-MM-DD_compression_<topic>.md`, unless the repository defines another session-log location.
3. Record:
   - objective and current acceptance criteria;
   - verified decisions and their evidence;
   - files changed with useful line pointers;
   - commands or checks run and their outcomes;
   - open questions and blockers;
   - one to three concrete next actions;
   - discarded hypotheses that should not contaminate the next task;
   - proposed reusable lessons, clearly marked as proposals.
4. Keep the note compact enough to resume from quickly. Do not paste the full conversation.
5. Report the saved path and counts of decisions, touched files, open questions, and next actions.

Do not modify memory automatically. The user may review candidates with `$academic-workflow-promote-memory`.
