#!/usr/bin/env bash
set -euo pipefail

BRANCH=$(git branch --show-current)

if [ "$BRANCH" = "main" ]; then
    echo "ERROR: already on main. Switch to the feature branch first." >&2
    exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "ERROR: working tree is not clean. Commit or stash changes first." >&2
    exit 1
fi

echo "==> Checking for WIP commits..."
git log --oneline -6

echo ""
echo "If WIP commits exist at the tip that touch the same concern, squash them now:"
echo "  git reset --soft <hash-before-wips> && git commit -m '<clean message>'"
echo "Then re-run this script."
read -rp "WIPs squashed (or none exist)? [y/N] " confirm
[ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { echo "Aborted."; exit 1; }

echo "==> Fetching and rebasing on origin/main..."
git fetch origin
git rebase origin/main

echo "==> Reviewing commits to squash..."
git log --oneline main..HEAD
echo ""
read -rp "Run interactive rebase to squash related-topic commits? [y/N] " squash
if [ "$squash" = "y" ] || [ "$squash" = "Y" ]; then
    git rebase -i main
fi

echo "==> Fast-forwarding main..."
git checkout main
git merge --ff-only "$BRANCH"

echo "==> Pushing main..."
git push origin main

echo "==> Deleting feature branch..."
git branch -d "$BRANCH"
git push origin --delete "$BRANCH" 2>/dev/null || echo "(remote branch not found, skipping)"

echo ""
git log --oneline -5
echo ""
echo "Merge complete. Branch '$BRANCH' deleted."
