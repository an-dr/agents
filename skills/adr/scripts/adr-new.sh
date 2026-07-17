#!/usr/bin/env bash
set -euo pipefail

title="${1:?Usage: adr-new.sh \"<title>\"}"

root="$(git rev-parse --show-toplevel)"
dir="$root/docs/adr"
mkdir -p "$dir"

max=0
for f in "$dir"/ADR-*.md; do
    [ -e "$f" ] || continue
    n="$(basename "$f" | sed -E 's/^ADR-0*([0-9]+).*/\1/')"
    if [ "$n" -gt "$max" ]; then max="$n"; fi
done
num="$(printf '%03d' $((max + 1)))"

slug="$(printf '%s' "$title" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
path="$dir/ADR-$num-$slug.md"

cat > "$path" <<EOF
# ADR-$num: $title

## Problem

## Decision

## Rationale

## Rejected alternatives
EOF

echo "Created $path"
