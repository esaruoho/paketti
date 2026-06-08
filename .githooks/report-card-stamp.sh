#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# report-card-stamp.sh — shared RESULT-LOG stamper for the report-card hooks.
# Installed by `convey hooks install`. Canonical source: Convey templates/hooks/.
#
# Called by pre-commit (the everyday direct-to-commit path) and post-merge (the
# merge / PR / non-ff-pull path). Appends a dated one-line entry to every report
# card whose WATCHed symbols appear on a changed line of the given diff.
#
# A card opts in with two header lines (works for any *.feature in the repo,
# whether under features/ or principles/<id>/intent.feature):
#     # WATCH: SymbolA SymbolB SymbolC ...
#     # RESULT-LOG >> (auto-maintained by convey hooks — newest below)
#
# Mapping is BY SYMBOL, not filename, so touching an unrelated part of a shared
# file does not tag every card. The scanned diff excludes the card homes
# (features/, principles/) and .githooks/ so a card edit can't self-tag.
#
# Args:
#   $1 DIFF_SPEC   git-diff range/selector, e.g. "ORIG_HEAD..HEAD" or "--cached"
#   $2 STAMP_DATE  YYYY-MM-DD to print
#   $3 TAG         middle text, e.g. "PR #3  merge 9493101" or "direct-commit"
#   $4 DEDUP_KEY   skip a card already containing this string (empty = no dedup)
#   $5 GIT_ADD     "1" => git add each stamped card (so a pre-commit stamp rides
#                  into the same commit); anything else => leave unstaged
#
# Always exits 0 — a hook must never abort the user's commit/merge.
# -----------------------------------------------------------------------------
DIFF_SPEC="${1:-}"; STAMP_DATE="${2:-}"; TAG="${3:-}"; DEDUP_KEY="${4:-}"; GIT_ADD="${5:-0}"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$REPO_ROOT" || exit 0

# Changed (+/-) lines of the diff, source only. `^[-+]` is anchored & tiny (no
# backtracking). Excludes card homes + .githooks/ so cards/hooks can't self-tag.
CHANGED_LINES="$(git diff $DIFF_SPEC -- . \
  ':(exclude)features/' ':(exclude)principles/' ':(exclude).githooks/' 2>/dev/null \
  | grep -E '^[-+]' || true)"
[ -n "$CHANGED_LINES" ] || exit 0

# Report cards = tracked *.feature files that carry both opt-in markers.
CARDS="$(git ls-files '*.feature' 2>/dev/null || true)"
[ -n "$CARDS" ] || exit 0

logged_any=0
while IFS= read -r card; do
  [ -n "$card" ] && [ -e "$card" ] || continue

  watch_line="$(grep -m1 '# WATCH:' "$card" 2>/dev/null || true)"
  [ -n "$watch_line" ] || continue                 # card not opted in
  grep -Fq 'RESULT-LOG >>' "$card" || continue     # no append marker

  # Dedup (merge path passes the sha; commit path passes empty = always log).
  if [ -n "$DEDUP_KEY" ] && grep -Fq "$DEDUP_KEY" "$card"; then
    continue
  fi

  tokens="${watch_line#*# WATCH:}"
  matched=""
  for tok in $tokens; do
    [ -n "$tok" ] || continue
    if printf '%s\n' "$CHANGED_LINES" | grep -Fq -- "$tok"; then
      matched="$matched $tok"
    fi
  done
  matched="${matched# }"
  [ -n "$matched" ] || continue                    # none of this card's symbols changed

  line="#   $STAMP_DATE  $TAG  touched: $matched"

  tmp="$(mktemp)" || continue
  awk -v m='RESULT-LOG >>' -v line="$line" '
    { print }
    (index($0, m) > 0 && !done) { print line; done = 1 }
  ' "$card" > "$tmp" && mv "$tmp" "$card"

  [ "$GIT_ADD" = "1" ] && git add -- "$card" 2>/dev/null

  echo "[report-card] stamped $card (touched:$matched)"
  logged_any=1
done <<EOF
$CARDS
EOF

if [ "$logged_any" = 1 ]; then
  if [ "$GIT_ADD" = "1" ]; then
    echo "[report-card] RESULT-LOG updated and staged into this commit."
  else
    echo "[report-card] RESULT-LOG updated in working tree — review & commit."
  fi
fi
exit 0
