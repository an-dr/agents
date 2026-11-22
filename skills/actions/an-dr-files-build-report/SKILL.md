---
name: an-dr-files-build-report
description: Build a written HTML page into a finished report - artifact path, embedded brand and status styles, offline diagrams, visual check, and latest copy. Use whenever a skill writes an HTML report.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.2.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-convention-html-repo-style an-dr-convention-html-report an-dr-files-find-destination
---

# Build a report

Defers: page content to the calling skill, page style to `an-dr-convention-html-repo-style`, report format to `an-dr-convention-html-report`, artifact paths and the latest copy to `an-dr-files-find-destination`.

## Take a path

Before writing any report or other generated artifact, take its path through `an-dr-files-find-destination`: the kind the calling skill declares in `an-dr.artifact.kind`, or a `--name` for a report the user asked for that no kind fits. Pass the printed stamp to every other file of the same artifact.

## Build the page

After writing the page and after every later edit:

```sh
python <an-dr-convention-html-repo-style>/scripts/embed-brand.py --path <page>.html
python <an-dr-convention-html-report>/scripts/embed-cockpit.py --path <page>.html
python <an-dr-convention-html-report>/scripts/render-mermaid.py --path <page>.html
```

- Check each exit code before continuing; a later success must not hide an earlier failure.
- `render-mermaid.py` needs a local Chrome or Edge, or `--browser <exe>`; it stops on a diagram that fails to parse and leaves the page unchanged.
- To change a diagram, edit its stored source or write a new `<pre class="mermaid">` block, then build again.

## Verify

After the final build, inspect screenshots in light and dark themes at desktop and 390 CSS-pixel phone width, and keep a visual-check record. Before capturing, read [references/visual-check.md](references/visual-check.md).

## Publish

Once the artifact is complete, pin it as the latest through `an-dr-files-find-destination` when the calling skill sets `an-dr.artifact.pin-latest: true`; skip it otherwise and for a one-off report.

## Output

Stamped path and latest path, reported to the user, with the visual-check result: complete, or blocked and why.

## Rules

- Never build an artifact path by hand, in prose or in a script.
- Never load Mermaid or any other script, style, or font from the network.
