#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPOSITORY_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd -P)"
QUARTO_ROOT="$REPOSITORY_ROOT/Quarto"
DOCS_ROOT="$REPOSITORY_ROOT/docs"
SLIDES_DESTINATION="$DOCS_ROOT/slides"
LECTURE="${1:-}"

if ! command -v quarto >/dev/null 2>&1; then
  echo "Required tool is missing: quarto" >&2
  exit 1
fi
if [[ ! -d "$QUARTO_ROOT" ]]; then
  echo "Missing Quarto directory: $QUARTO_ROOT" >&2
  exit 1
fi
mkdir -p "$SLIDES_DESTINATION"

shopt -s nullglob
if [[ -n "$LECTURE" ]]; then
  CANDIDATES=("$QUARTO_ROOT"/"$LECTURE"*.qmd)
  FILTERED=()
  for qmd in "${CANDIDATES[@]}"; do
    [[ "$(basename -- "$qmd")" == *_backup* ]] || FILTERED+=("$qmd")
  done
  CANDIDATES=("${FILTERED[@]}")
  if [[ ${#CANDIDATES[@]} -ne 1 ]]; then
    echo "Expected one QMD target for '$LECTURE'; found ${#CANDIDATES[@]}." >&2
    exit 1
  fi
else
  CANDIDATES=()
  for qmd in "$QUARTO_ROOT"/*.qmd; do
    [[ "$(basename -- "$qmd")" == *_backup* ]] || CANDIDATES+=("$qmd")
  done
fi

for qmd in "${CANDIDATES[@]}"; do
  quarto render "$qmd"
done

for html in "$QUARTO_ROOT"/*.html; do
  cp -f "$html" "$SLIDES_DESTINATION/"
  base="$(basename -- "$html" .html)"
  asset_source="$QUARTO_ROOT/${base}_files"
  if [[ -d "$asset_source" ]]; then
    asset_target="$SLIDES_DESTINATION/${base}_files"
    mkdir -p "$asset_target"
    cp -R "$asset_source"/. "$asset_target/"
  fi
done

if [[ -d "$REPOSITORY_ROOT/Slides" ]]; then
  for pdf in "$REPOSITORY_ROOT"/Slides/*.pdf; do cp -f "$pdf" "$SLIDES_DESTINATION/"; done
fi

CODE_DESTINATION="$DOCS_ROOT/files/code"
mkdir -p "$CODE_DESTINATION"
if [[ -d "$REPOSITORY_ROOT/scripts/R" ]]; then
  for r_file in "$REPOSITORY_ROOT"/scripts/R/*.R; do cp -f "$r_file" "$CODE_DESTINATION/"; done
fi

if [[ -d "$REPOSITORY_ROOT/Figures" ]]; then
  mkdir -p "$DOCS_ROOT/Figures"
  cp -R "$REPOSITORY_ROOT/Figures"/. "$DOCS_ROOT/Figures/"
fi
shopt -u nullglob

echo "Rendered and synchronized outputs under: $DOCS_ROOT"
