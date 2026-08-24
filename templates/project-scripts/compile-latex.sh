#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: bash scripts/compile-latex.sh <target.tex-or-name>" >&2
  exit 2
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPOSITORY_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
SLIDES_ROOT="$REPOSITORY_ROOT/Slides"
TARGET="$1"

if [[ -f "$TARGET" ]]; then
  TARGET_DIR="$(cd -- "$(dirname -- "$TARGET")" && pwd -P)"
  TEX_PATH="$TARGET_DIR/$(basename -- "$TARGET")"
else
  CANDIDATE="$SLIDES_ROOT/$TARGET"
  [[ "$CANDIDATE" == *.tex ]] || CANDIDATE="${CANDIDATE}.tex"
  if [[ -f "$CANDIDATE" ]]; then
    TEX_PATH="$CANDIDATE"
  else
    shopt -s nullglob
    MATCHES=("$SLIDES_ROOT"/"$TARGET"*.tex)
    shopt -u nullglob
    if [[ ${#MATCHES[@]} -ne 1 ]]; then
      echo "Expected one TeX target for '$TARGET'; found ${#MATCHES[@]}." >&2
      exit 1
    fi
    TEX_PATH="${MATCHES[0]}"
  fi
fi

if [[ "$TEX_PATH" != *.tex ]]; then
  echo "Target must be a .tex file: $TEX_PATH" >&2
  exit 1
fi
if ! command -v xelatex >/dev/null 2>&1; then
  echo "Required tool is missing: xelatex" >&2
  exit 1
fi

WORKING_DIRECTORY="$(cd -- "$(dirname -- "$TEX_PATH")" && pwd -P)"
BASE_NAME="$(basename -- "$TEX_PATH" .tex)"
TEX_PATH="$WORKING_DIRECTORY/$BASE_NAME.tex"
export TEXINPUTS="$REPOSITORY_ROOT/Preambles:${TEXINPUTS:-}"
export BIBINPUTS="$REPOSITORY_ROOT:${BIBINPUTS:-}"

pushd "$WORKING_DIRECTORY" >/dev/null
xelatex -interaction=nonstopmode -halt-on-error "$BASE_NAME.tex"
if [[ -f "$BASE_NAME.aux" ]] && grep -Fq '\bibdata' "$BASE_NAME.aux"; then
  if ! command -v bibtex >/dev/null 2>&1; then
    echo "The document uses a bibliography, but bibtex is missing." >&2
    exit 1
  fi
  bibtex "$BASE_NAME"
fi
xelatex -interaction=nonstopmode -halt-on-error "$BASE_NAME.tex"
xelatex -interaction=nonstopmode -halt-on-error "$BASE_NAME.tex"
popd >/dev/null

PDF_PATH="${TEX_PATH%.tex}.pdf"
LOG_PATH="${TEX_PATH%.tex}.log"
if [[ ! -f "$PDF_PATH" ]]; then
  echo "Compilation finished without producing $PDF_PATH" >&2
  exit 1
fi
if [[ -f "$LOG_PATH" ]]; then
  if grep -Eq 'LaTeX Warning:.*undefined|There were undefined references|Package .* Warning: Citation .* undefined' "$LOG_PATH"; then
    echo "Compilation produced unresolved references or citations. Inspect: $LOG_PATH" >&2
    exit 1
  fi
  OVERFULL_COUNT="$(grep -Ec 'Overfull \\[hv]box' "$LOG_PATH" || true)"
  if [[ "$OVERFULL_COUNT" -gt 0 ]]; then
    echo "Warning: compilation produced $OVERFULL_COUNT overfull box warning(s). Inspect: $LOG_PATH" >&2
  fi
fi

echo "Compiled: $PDF_PATH"
