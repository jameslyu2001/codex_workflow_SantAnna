#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 is required to verify the installation." >&2
  exit 1
fi

exec python3 "$SCRIPT_DIR/scripts/verify_install_macos.py" "$@"
