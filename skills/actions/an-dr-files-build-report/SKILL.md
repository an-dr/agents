---
name: an-dr-files-build-report
description: Build a written HTML page into a finished report - artifact path, embedded brand and status styles, offline diagrams, visual check, and latest copy. Use whenever a skill writes an HTML report, or needs a path for any generated artifact.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-convention-artifact-layout an-dr-convention-html-report
---

# Build a report

Defers: page content to the calling skill, page format to `an-dr-convention-html-report`, artifact locations to `an-dr-convention-artifact-layout`.

## Take a path

Before writing any report or other generated artifact:

```powershell
pwsh <an-dr-convention-artifact-layout>/scripts/new-artifact-path.ps1 -Kind <kind> -Extension <extension> [-Stamp <YYYY-MM-DD_hh-mm>] [-RepositoryRoot <path>]
```

- Creates the kind folder and its `.gitignore`, prints the file path.
- Without `-Stamp` it uses the current minute; pass the printed stamp as `-Stamp` for every other file of the same artifact.
- Rejects an unregistered kind, an uppercase extension, a malformed stamp.
- A new kind is registered in that convention's kind list in the same change.

## Build the page

After writing the page and after every later edit:

```powershell
pwsh <an-dr-convention-html-report>/scripts/embed-brand.ps1 -Path <page>.html
if ($LASTEXITCODE -ne 0) { throw 'Brand embedding failed.' }
pwsh <an-dr-convention-html-report>/scripts/embed-cockpit.ps1 -Path <page>.html
if ($LASTEXITCODE -ne 0) { throw 'Status stylesheet embedding failed.' }
pwsh <an-dr-convention-html-report>/scripts/render-mermaid.ps1 -Path <page>.html
if ($LASTEXITCODE -ne 0) { throw 'Diagram rendering failed.' }
```

- Check each exit code before continuing; a later success must not hide an earlier failure.
- `render-mermaid.ps1` needs a local Chrome or Edge, or `-Browser <exe>`; it stops on a diagram that fails to parse and leaves the page unchanged.
- To change a diagram, edit its stored source or write a new `<pre class="mermaid">` block, then build again.

## Verify

After the final build, inspect screenshots in light and dark themes at desktop and 390 CSS-pixel phone width, and keep a visual-check record. Before capturing, read [references/visual-check.md](references/visual-check.md).

## Publish

Once the artifact is complete:

```powershell
pwsh <an-dr-convention-artifact-layout>/scripts/publish-latest.ps1 -Path <artifact-file>
```

Replaces every `<kind>-latest.*` with copies of all files sharing the artifact's stamp; prints the copies.

## Output

Stamped path and latest path, reported to the user, with the visual-check result: complete, or blocked and why.

## Rules

- Never build an artifact path by hand, in prose or in a script.
- Never load Mermaid or any other script, style, or font from the network.
