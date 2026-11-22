# an-dr-files-find-destination

Gives every generated output its place by the artifact layout, and keeps the latest copy current for kinds that want one.

## When it runs

Before a skill writes a report, review, or other non-repository output, and again after the output is finished when its kind keeps a latest copy.

## How it works

- Input: the artifact kind, if the calling skill declares one, and whether the latest copy is pinned.
- `scripts/find-destination.py` prints the path for a kind, or for a named one-off output without a kind; it is the one implementation of the layout, so callers never spell a path.
- `scripts/pin-latest.py` pins a finished artifact as its kind's latest copy.

## What you get

A predictable path for every artifact, and one stable filename for the newest of each pinned kind.

## Related skills

- [an-dr-convention-artifact-layout](../../conventions/an-dr-convention-artifact-layout/README.md) — the layout this applies.
- [an-dr-files-build-report](../an-dr-files-build-report/README.md) — takes its report paths here.
