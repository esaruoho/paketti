#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

if ! command -v python3 >/dev/null 2>&1; then
  echo "refresh-generated-docs: python3 is required" >&2
  exit 1
fi

if ! command -v luajit >/dev/null 2>&1 && ! command -v lua >/dev/null 2>&1; then
  echo "refresh-generated-docs: luajit or lua is required for the .spine harness" >&2
  exit 1
fi

mkdir -p docs

echo "==> Generating spine truth and coverage"
python3 .spine/build.py "$ROOT"

echo "==> Generating feature map and MIDI gaps"
python3 .spine/features.py "$ROOT/.spine/spine-true.json" "$ROOT"

echo "==> Generating architecture notes"
if [ -x .spine/archof ]; then
  .spine/archof "$ROOT" --write
  mv -f ARCHITECTURE.md docs/ARCHITECTURE.md
else
  echo "refresh-generated-docs: skipping architecture notes; .spine/archof is not executable" >&2
fi

echo "==> Generating function index"
python3 .spine/functions.py "$ROOT"

echo "==> Syncing manual generated blocks"
python3 .spine/manual-sync.py "$ROOT"
python3 .spine/changelog-manual.py "$ROOT"

echo
echo "Generated-doc changes:"
git status --short -- \
  .spine/spine-true.json \
  docs/SPINE-TRUE.md \
  docs/COVERAGE.md \
  docs/ARCHITECTURE.md \
  docs/FEATURE-MAP.md \
  docs/MIDI-GAPS.md \
  docs/PAKETTI-FUNCTIONS.md \
  docs/paketti-functions.json \
  docs/FEATURE-DESCRIPTIONS.md \
  manual/Experimental.md
