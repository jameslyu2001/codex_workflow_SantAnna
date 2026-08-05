"""Shared helpers for the Codex academic workflow hooks."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
from pathlib import Path
from typing import Any, Optional


def read_input() -> dict[str, Any]:
    import sys

    try:
        value = json.load(sys.stdin)
        return value if isinstance(value, dict) else {}
    except Exception:
        return {}


def repository_root(data: dict[str, Any]) -> Optional[Path]:
    cwd = Path(str(data.get("cwd") or Path.cwd())).resolve()
    try:
        result = subprocess.run(
            ["git", "-C", str(cwd), "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        if result.returncode == 0 and result.stdout.strip():
            return Path(result.stdout.strip()).resolve()
    except Exception:
        pass
    return cwd if cwd.is_dir() else None


def workflow_enabled(root: Optional[Path]) -> bool:
    return bool(root and (root / ".codex" / "academic-workflow.json").is_file())


def session_state_dir(root: Path) -> Path:
    key = hashlib.sha256(str(root).encode("utf-8")).hexdigest()[:16]
    target = Path.home() / ".codex" / "academic-workflow-state" / "sessions" / key
    target.mkdir(parents=True, exist_ok=True)
    return target


def active_plan(root: Path) -> Optional[dict[str, Any]]:
    plans = root / "quality_reports" / "plans"
    if not plans.is_dir():
        return None
    candidates = sorted(plans.glob("*.md"), key=lambda path: path.stat().st_mtime, reverse=True)
    for path in candidates[:5]:
        try:
            text = path.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        match = re.search(
            r"^\s*\**\s*status\s*\**\s*:\s*\**\s*"
            r"(draft|approved|completed|implemented|in[ -]?progress)",
            text,
            re.IGNORECASE | re.MULTILINE,
        )
        value = match.group(1).lower() if match else "in-progress"
        if value.startswith(("completed", "implemented")):
            continue
        status = "approved" if value.startswith("approved") else (
            "draft" if value.startswith("draft") else "in-progress"
        )
        current = next(
            (line.replace("- [ ]", "", 1).strip() for line in text.splitlines() if "- [ ]" in line),
            None,
        )
        return {"path": str(path), "name": path.name, "status": status, "current_task": current}
    return None


def patch_paths(command: str) -> list[str]:
    return re.findall(r"^\*\*\* (?:Add|Update|Delete) File:\s*(.+?)\s*$", command, re.MULTILINE)


def emit(value: dict[str, Any]) -> None:
    import sys

    json.dump(value, sys.stdout, ensure_ascii=False)
