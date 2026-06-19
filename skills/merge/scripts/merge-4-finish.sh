#!/usr/bin/env bash
set -euo pipefail

BRANCH=$(git branch --show-current)
if [ "$BRANCH" = "main" ]; then
    echo "ERROR: already on main." >&2
    exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "ERROR: working tree is not clean." >&2
    exit 1
fi

echo "==> Fast-forwarding main..."
git checkout main
git merge --ff-only "$BRANCH"

echo "==> Pushing main..."
git push origin main

echo "==> Deleting feature branch '$BRANCH'..."
git branch -d "$BRANCH"
git push origin --delete "$BRANCH" 2>/dev/null || echo "(remote branch not found, skipping)"

echo ""
git log --oneline -5
echo ""
echo "Merge complete. Branch '$BRANCH' deleted."
