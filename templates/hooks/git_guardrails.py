"""PreToolUse guardrails adapted to Codex's hook schema."""

from __future__ import annotations

import os
import re
from pathlib import Path

from _common import emit, patch_paths, read_input


GIT_OPTIONS = (
    r"(?:-C\s+\S+\s+|-c\s+\S+\s+|--git-dir(?:=\S+\s+|\s+\S+\s+)|"
    r"--work-tree(?:=\S+\s+|\s+\S+\s+)|--no-pager\s+|--paginate\s+|-p\s+)*"
)
GIT_DENY = [
    (re.compile(r"\bgit\s+" + GIT_OPTIONS + r"reset\s+--hard\b", re.I),
     "git reset --hard irreversibly discards uncommitted work. Use git stash or restore specific paths."),
    (re.compile(r"\bgit\s+" + GIT_OPTIONS + r"clean\b.*(--force\b|(?<![\w-])-[a-z]*f)", re.I),
     "git clean -f deletes untracked files. Inspect with git clean -n and remove explicit targets."),
    (re.compile(r"\bgit\s+" + GIT_OPTIONS + r"push\b.*(--force(?![\w-])|(?<!-)\s-f\b)", re.I),
     "git push --force rewrites remote history. Use --force-with-lease only with explicit authorization."),
    (re.compile(r"\bgit\s+" + GIT_OPTIONS + r"add\s+(?:--\s+)?(-A\b|--all\b|\.(?:\s|$)|:/)", re.I),
     "Blanket staging can include secrets or unrelated work. Stage explicit paths."),
    (re.compile(r"\bgit\s+" + GIT_OPTIONS + r"(checkout|restore)\s+(--\s+)?\.(?:\s|$)", re.I),
     "Mass discard of working-tree changes is irreversible. Restore specific files or stash first."),
]
HARDCODED_PATH = re.compile(
    r"(/Users/[^/\s'\")]+|/home/[^/\s'\")]+|[A-Za-z]:[\\/]+Users[\\/]+[^\\/\s'\"]+)",
    re.I,
)
CODE_EXTENSIONS = {".r", ".rmd", ".qmd", ".do", ".py", ".jl"}


def deny(reason: str) -> None:
    emit({
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": f"Blocked by the Codex academic workflow: {reason}",
        }
    })


def main() -> int:
    data = read_input()
    tool = str(data.get("tool_name") or "")
    tool_input = data.get("tool_input") if isinstance(data.get("tool_input"), dict) else {}
    command = str(tool_input.get("command") or "")

    if tool == "Bash":
        for pattern, reason in GIT_DENY:
            if pattern.search(command):
                deny(reason)
                return 0
        return 0

    if tool not in {"apply_patch", "Edit", "Write"}:
        return 0
    paths = patch_paths(command)
    if not any(Path(path).suffix.lower() in CODE_EXTENSIONS for path in paths):
        return 0
    match = HARDCODED_PATH.search(command)
    if not match:
        return 0
    reason = (
        f"Hardcoded machine path '{match.group(0)}' in academic code harms reproducibility. "
        "Use a project-relative path or configuration value."
    )
    if os.environ.get("CODEX_ACADEMIC_STRICT_PATHS") == "1":
        deny(reason)
    else:
        emit({
            "systemMessage": reason,
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "additionalContext": reason,
            },
        })
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception:
        raise SystemExit(0)
