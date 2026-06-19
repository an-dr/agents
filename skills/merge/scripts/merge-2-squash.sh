#!/usr/bin/env bash
set -euo pipefail

HASH="${1:?Usage: merge-2-squash.sh <hash-or-ref> '<commit message>'}"
MESSAGE="${2:?Usage: merge-2-squash.sh <hash-or-ref> '<commit message>'}"

BRANCH=$(git branch --show-current)
if [ "$BRANCH" = "main" ]; then
    echo "ERROR: already on main." >&2
    exit 1
fi

echo "==> Squashing commits since '$HASH' into one commit..."
git reset --soft "$HASH"
git commit -m "$MESSAGE"
echo ""
echo "==> Current log:"
git log --oneline -6
