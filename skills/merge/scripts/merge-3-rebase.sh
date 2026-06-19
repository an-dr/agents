#!/usr/bin/env bash
set -euo pipefail

BRANCH=$(git branch --show-current)
if [ "$BRANCH" = "main" ]; then
    echo "ERROR: already on main." >&2
    exit 1
fi

echo "==> Fetching origin..."
git fetch origin
echo "==> Rebasing on origin/main..."
git rebase origin/main
echo ""
echo "==> Commits on this branch since main:"
git log --oneline main..HEAD
