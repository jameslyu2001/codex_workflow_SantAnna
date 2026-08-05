"""Restore plan and session-log context after Codex compaction or resume."""

from __future__ import annotations

import json

from _common import active_plan, emit, read_input, repository_root, session_state_dir, workflow_enabled


def main() -> int:
    data = read_input()
    if data.get("source") not in {"compact", "resume"}:
        return 0
    root = repository_root(data)
    if not workflow_enabled(root) or root is None:
        return 0
    state_path = session_state_dir(root) / "pre-compact-state.json"
    try:
        state = json.loads(state_path.read_text(encoding="utf-8")) if state_path.exists() else {}
        if state_path.exists():
            state_path.unlink()
    except Exception:
        state = {}
    plan = active_plan(root)
    logs = root / "quality_reports" / "session_logs"
    log_files = sorted(logs.glob("*.md"), key=lambda path: path.stat().st_mtime, reverse=True) if logs.is_dir() else []
    if not state and not plan and not log_files:
        return 0

    lines = ["[Academic workflow state restored after Codex compaction/resume]"]
    saved_plan = state.get("plan") if isinstance(state, dict) else None
    if saved_plan:
        lines.append(f"Saved plan: {saved_plan.get('name')} ({saved_plan.get('status')})")
        if saved_plan.get("current_task"):
            lines.append(f"Saved next task: {saved_plan.get('current_task')}")
    for decision in state.get("decisions", [])[-3:] if isinstance(state, dict) else []:
        lines.append(f"Recent decision: {decision}")
    if plan:
        lines.append(f"Current plan: {plan.get('path')} ({plan.get('status')})")
        if plan.get("current_task"):
            lines.append(f"Current next task: {plan.get('current_task')}")
    if log_files:
        lines.append(f"Latest session log: {log_files[0].relative_to(root)}")
    lines.append("Before continuing, inspect the active plan and git status/diff.")
    message = "\n".join(lines)
    emit({
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": message,
        }
    })
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        raise SystemExit(0)
