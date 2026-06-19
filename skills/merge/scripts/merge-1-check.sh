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

echo "Branch: $BRANCH"
echo ""
echo "==> Recent commits (check for WIPs at the tip):"
git log --oneline -6
echo ""
echo "==> Commits on this branch since main:"
git log --oneline main..HEAD
echo ""
echo "Preconditions OK."
echo "Next steps:"
echo "  [optional] merge-2-squash.sh <hash-before-wips> '<msg>'  # squash WIP commits"
echo "             merge-3-rebase.sh"
echo "  [optional] merge-2-squash.sh main '<msg>'                # squash topic commits"
echo "             merge-4-finish.sh"
