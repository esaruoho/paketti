#!/bin/bash
# capture-front-window.sh — capture JUST the frontmost Renoise dialog window (clean, cropped),
# so a dialog screenshot has no desktop / menu-bar / other-app clutter. macOS only.
#
#   capture-front-window.sh --precompile     # build the window-lister binary once (cache)
#   capture-front-window.sh <output.png>     # capture the front dialog window to <output.png>
#
# Resolves the front dialog's CoreGraphics window ID via a tiny compiled Swift helper
# (no Accessibility permission needed), then `screencapture -l<id>`. Falls back to a
# full-screen grab if the window ID can't be resolved (e.g. swiftc unavailable).
DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$DIR/winlist.swift"
BIN="${TMPDIR:-/tmp}/paketti-winlist"

precompile() {
  # (Re)build when the binary is missing OR older than the source (handles updates).
  if command -v swiftc >/dev/null 2>&1 && [ -f "$SRC" ]; then
    if [ ! -x "$BIN" ] || [ "$SRC" -nt "$BIN" ]; then
      swiftc -O "$SRC" -o "$BIN" 2>/dev/null || true
    fi
  fi
}

if [ "$1" = "--precompile" ]; then
  precompile
  exit 0
fi

OUT="$1"
[ -z "$OUT" ] && { echo "usage: $0 <output.png>"; exit 1; }
precompile

ID=""
[ -x "$BIN" ] && ID="$("$BIN" 2>/dev/null | head -1 | cut -f1)"

if [ -n "$ID" ]; then
  screencapture -x -o -l"$ID" "$OUT"     # just the dialog window, cropped, no shadow
else
  screencapture -x -o "$OUT"             # fallback: whole screen
fi
