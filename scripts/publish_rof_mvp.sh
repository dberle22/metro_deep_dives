#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QMD_PATH="$ROOT_DIR/notebooks/retail_opportunity_finder/integration/qmd/retail_opportunity_finder_mvp.qmd"
HTML_SRC="$ROOT_DIR/notebooks/retail_opportunity_finder/integration/qmd/retail_opportunity_finder_mvp.html"
ASSETS_SRC_DIR="$ROOT_DIR/notebooks/retail_opportunity_finder/integration/qmd/retail_opportunity_finder_mvp_files"
PUBLISH_DIR="$ROOT_DIR/docs/rof-mvp"

if ! command -v quarto >/dev/null 2>&1; then
  echo "Error: Quarto CLI is not installed or not on PATH." >&2
  exit 1
fi

mkdir -p "$PUBLISH_DIR"

echo "Rendering Quarto report..."
quarto render "$QMD_PATH"

echo "Syncing publish artifacts to docs/rof-mvp..."
cp "$HTML_SRC" "$PUBLISH_DIR/index.html"
rsync -a --delete "$ASSETS_SRC_DIR/" "$PUBLISH_DIR/retail_opportunity_finder_mvp_files/"

echo "Done. Published site payload is in: $PUBLISH_DIR"
