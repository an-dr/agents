---
name: an-dr-files-find-destination
description: Find where a generated artifact goes from its kind, or a named one-off path without a kind, applying the artifact layout, and pin a finished artifact as its kind's latest copy. Use before writing any non-repository output file, and after finishing one whose kind keeps a latest copy.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-convention-artifact-layout
---

# Find destination

Defers: the layout itself to `an-dr-convention-artifact-layout`.

## Inputs

| Input    | Value                                                                                     |
| -------- | ----------------------------------------------------------------------------------------- |
| kind     | the calling skill's `an-dr.artifact.kind`; absent for a one-off output the user asked for |
| internal | the calling skill's `an-dr.artifact.internal`; `--internal` places it as internal state   |
| pin      | the calling skill's `an-dr.artifact.pin-latest`; never without a kind                     |

## Find the path

```sh
python <skill>/scripts/find-destination.py <extension> [--kind <kind> [--internal] | --name <name>] [--stamp <YYYY-MM-DD_hh-mm>] [--repository-root <path>]
```

- Creates the folder and its git ignore, prints the file path.
- Without `--kind`, `--name` is required, in lowercase hyphenated words, and the path is a one-off without a kind.
- Without `--stamp` it takes the current minute; pass the printed stamp to every other file of the same artifact.
- Rejects a kind or name that is not lowercase hyphenated words, `--name` beside `--kind`, `--internal` without `--kind`, an uppercase extension, a malformed stamp.

## Pin the latest

Only when pin is yes, once the artifact is complete:

```sh
python <skill>/scripts/pin-latest.py <artifact-file>
```

Replaces the kind's latest copy with all files sharing the artifact's stamp and prints the copies; refuses a one-off or internal artifact.

## Output

The stamped path, and the latest copies when pinned, reported to the user.

## Rules

- Never build an artifact path by hand, in prose or in a script.
