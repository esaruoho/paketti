#!/usr/bin/env bash
set -euo pipefail

# 1. Fetch all tags and prune deleted refs
git fetch --prune --tags

# 2. Determine the newest tag by creation date
newest=$(git for-each-ref --sort=-creatordate \
          --format='%(refname:strip=2)' refs/tags \
          | head -n1)

echo "👉 Keeping only: $newest"

# 3. Delete all other tags locally
echo "Deleting other tags locally…"
git tag | grep -vxF "$newest" | xargs -r git tag -d

# 4. Delete all other tags on origin
echo "Deleting other tags on origin…"
git ls-remote --tags origin \
  | awk '{print $2}' \
  | sed 's#refs/tags/##' \
  | grep -vxF "$newest" \
  | xargs -r -I{} git push origin --delete {}

echo "Done. Only '$newest' remains locally and on origin."

