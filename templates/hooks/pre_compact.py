"""Capture durable academic state immediately before Codex compaction."""

from __future__ import annotations

import json
import os
import re
from datetime import datetime

from _common import active_plan, emit, read_input, repository_root, session_state_dir, workflow_enabled


def recent_decisions(root, limit: int = 3) -> list[str]:
    logs = root / "quality_reports" / "session_logs"
    if not logs.is_dir():
        return []
    files = sorted(logs.glob("*.md"), key=lambda path: path.stat().st_mtime, reverse=True)
    if not files:
        return []
    try:
        lines = files[0].read_text(encoding="utf-8", errors="replace").splitlines()[-80:]
    except OSError:
        return []
    results = []
    for line in lines:
        match = re.search(r"(?:Decision|Decided|Chose):\s*(.+)", line, re.I)
        if match and len(match.group(1).strip()) > 10:
            results.append(match.group(1).strip()[:200])
            if len(results) >= limit:
                break
    return results


def should_block(root, plan) -> tuple[bool, str]:
    if os.environ.get("CODEX_ACADEMIC_PRECOMPACT_BLOCK_ON_DRAFT") != "1":
        return False, ""
    if not plan or plan.get("status") != "draft":
        return False, ""
    sentinel = session_state_dir(root) / "precompact-block-sentinel.json"
    try:
        previous = json.loads(sentinel.read_text(encoding="utf-8")) if sentinel.exists() else {}
        if previous.get("last_blocked_plan") == plan.get("path"):
            return False, ""
        sentinel.write_text(
            json.dumps({"last_blocked_plan": plan.get("path"), "when": datetime.now().isoformat()}),
            encoding="utf-8",
        )
    except Exception:
        return False, ""
    return True, (
        f"Compaction paused once because {plan.get('name')} is still DRAFT. "
        "Approve the plan or retry compaction to continue; this guard blocks each draft plan only once."
    )


def main() -> int:
    data = read_input()
    root = repository_root(data)
    if not workflow_enabled(root) or root is None:
        return 0
    plan = active_plan(root)
    decisions = recent_decisions(root)
    block, reason = should_block(root, plan)
    if block:
        emit({"decision": "block", "reason": reason})
        return 0

    state = {
        "trigger": data.get("trigger", "auto"),
        "timestamp": datetime.now().isoformat(),
        "plan": plan,
        "decisions": decisions,
    }
    try:
        (session_state_dir(root) / "pre-compact-state.json").write_text(
            json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8"
        )
    except OSError:
        pass

    logs = root / "quality_reports" / "session_logs"
    files = sorted(logs.glob("*.md"), key=lambda path: path.stat().st_mtime, reverse=True) if logs.is_dir() else []
    if files:
        try:
            with files[0].open("a", encoding="utf-8") as handle:
                handle.write(
                    f"\n---\n**Codex context compaction ({state['trigger']}) at "
                    f"{datetime.now().strftime('%H:%M')}**\n"
                )
        except OSError:
            pass
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        raise SystemExit(0)
