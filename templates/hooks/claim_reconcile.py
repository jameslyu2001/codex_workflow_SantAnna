"""Flag tracked numerical claims after an analysis input changes."""

from __future__ import annotations

import json
import re
import time
from pathlib import Path

from _common import emit, patch_paths, read_input, repository_root, session_state_dir, workflow_enabled


WATCH = re.compile(r"(^|/)scripts/.*\.(r|do|py|jl)$|(^|/)scripts/.*/_outputs/", re.I)
THROTTLE_SECONDS = 300


def main() -> int:
    data = read_input()
    root = repository_root(data)
    if not workflow_enabled(root):
        return 0
    tool_input = data.get("tool_input") if isinstance(data.get("tool_input"), dict) else {}
    paths = []
    if tool_input.get("file_path"):
        paths.append(str(tool_input["file_path"]))
    paths.extend(patch_paths(str(tool_input.get("command") or "")))
    changed = next((path.replace("\\", "/") for path in paths if WATCH.search(path.replace("\\", "/"))), None)
    if not changed or root is None:
        return 0
    try:
        changed = str(Path(changed).resolve().relative_to(root.resolve())).replace("\\", "/")
    except Exception:
        changed = changed.lstrip("./")

    passports = sorted((root / "quality_reports" / "passports").glob("*.yaml"))
    if not passports:
        return 0
    state_path = session_state_dir(root) / "claim-reconcile.json"
    try:
        state = json.loads(state_path.read_text(encoding="utf-8"))
    except Exception:
        state = {}
    now = time.time()
    if now - float(state.get(changed, 0)) < THROTTLE_SECONDS:
        return 0
    state[changed] = now
    try:
        state_path.write_text(json.dumps(state, indent=2), encoding="utf-8")
    except OSError:
        pass

    affected = []
    for passport in passports:
        try:
            text = passport.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        count = sum(
            1 for line in text.splitlines()
            if ("source_file" in line or "output_file" in line) and changed in line.replace("\\", "/")
        )
        if count:
            affected.append((passport.name, count))
    if not affected:
        return 0

    total = sum(count for _, count in affected)
    detail = ", ".join(f"{name} ({count})" for name, count in affected)
    message = (
        f"{changed} changed; {total} tracked claim(s) may now be stale [{detail}]. "
        "Run $academic-workflow-audit-reproducibility before relying on them."
    )
    emit({
        "systemMessage": message,
        "hookSpecificOutput": {"hookEventName": "PostToolUse", "additionalContext": message},
    })
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        raise SystemExit(0)
