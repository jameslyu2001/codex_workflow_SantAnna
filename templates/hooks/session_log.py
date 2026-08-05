"""Write a compact project session log when a Codex turn stops with changes."""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
from datetime import datetime

from _common import active_plan, emit, read_input, repository_root, session_state_dir, workflow_enabled


def git_status(root) -> str:
    try:
        result = subprocess.run(
            ["git", "-C", str(root), "status", "--porcelain"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        return result.stdout if result.returncode == 0 else ""
    except Exception:
        return ""


def uncompiled(root) -> list[str]:
    findings = []
    for folder, source_glob, extension in (("Slides", "*.tex", ".pdf"), ("Quarto", "*.qmd", ".html")):
        source_root = root / folder
        if not source_root.is_dir():
            continue
        for source in source_root.glob(source_glob):
            output = source.with_suffix(extension)
            try:
                if not output.exists() or source.stat().st_mtime > output.stat().st_mtime:
                    findings.append(f"{source.relative_to(root)} -> no fresh {extension}")
            except OSError:
                continue
    return findings


def main() -> int:
    data = read_input()
    if data.get("stop_hook_active"):
        return 0
    root = repository_root(data)
    if not workflow_enabled(root) or root is None:
        return 0
    status = git_status(root)
    if not status.strip():
        return 0
    digest = hashlib.sha256(status.encode("utf-8")).hexdigest()
    state_path = session_state_dir(root) / "session-log-state.json"
    try:
        previous = json.loads(state_path.read_text(encoding="utf-8")).get("last_hash")
    except Exception:
        previous = None
    if previous == digest:
        return 0

    logs = root / "quality_reports" / "session_logs"
    logs.mkdir(parents=True, exist_ok=True)
    now = datetime.now()
    path = logs / f"{now.strftime('%Y-%m-%d')}_auto.md"
    changed = [line.strip() for line in status.splitlines() if line.strip()][:30]
    plan = active_plan(root)
    stale = uncompiled(root)
    lines = []
    if not path.exists():
        lines.extend([
            f"# Session log — {now.strftime('%Y-%m-%d')} (Codex auto)",
            "",
            "_Written by the global academic workflow Stop hook for initialized projects._",
            "",
        ])
    lines.append(f"## {now.strftime('%H:%M')} — {len(changed)} changed path(s)")
    if plan:
        lines.append(f"\n**Active plan:** {plan.get('name')} ({plan.get('status')})")
    lines.append("\n**Changed:**")
    lines.extend(f"- `{line}`" for line in changed)
    if stale:
        lines.append("\n**Uncompiled artifacts:**")
        lines.extend(f"- {item}" for item in stale)
    lines.append("")
    try:
        with path.open("a", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")
        state_path.write_text(json.dumps({"last_hash": digest}), encoding="utf-8")
    except OSError:
        return 0

    if stale and os.environ.get("CODEX_ACADEMIC_COMPILE_GATE") == "block":
        reason = (
            "Uncompiled academic artifacts remain: " + "; ".join(stale) +
            ". Run $academic-workflow-compile-latex or $academic-workflow-deploy before stopping."
        )
        emit({"decision": "block", "reason": reason})
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        raise SystemExit(0)
