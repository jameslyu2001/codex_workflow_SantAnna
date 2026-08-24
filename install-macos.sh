#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ "$(uname -s)" != "Darwin" && "${CODEX_ACADEMIC_ALLOW_NON_MACOS_TESTING:-}" != "1" ]]; then
  echo "This installer is for macOS. On Windows, use install.ps1." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 is required for installation and Codex hooks." >&2
  echo "Install it first (for example: brew install python)." >&2
  exit 1
fi

exec python3 "$SCRIPT_DIR/scripts/install_macos.py" "$@"
