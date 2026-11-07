---
name: an-dr-files-build-report
description: Build a written HTML page into a finished report - take its artifact path, embed the brand and status styles, render diagrams offline, check it visually, and publish it as the latest. Use whenever a skill writes an HTML report, or needs a path for any generated artifact.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-convention-artifact-layout an-dr-convention-html-report
---

# Build a report

Turns a page that another skill wrote into a finished report artifact. The calling skill owns what the page says; `an-dr-convention-html-report` describes what a correct page looks like, and `an-dr-convention-artifact-layout` where artifacts live.

## Take a path

Take the path before writing, for a report or for any other generated artifact:

```powershell
pwsh <an-dr-convention-artifact-layout>/scripts/new-artifact-path.ps1 -Kind <kind> -Extension <extension> [-Stamp <YYYY-MM-DD_hh-mm>] [-RepositoryRoot <path>]
```

It creates the kind folder and its `.gitignore`, then prints the file path. Without `-Stamp` it takes the current minute; pass the printed stamp as `-Stamp` for every other file of the same artifact. It rejects an unregistered kind, an uppercase extension, and a malformed stamp. A skill that writes a new kind registers it in that convention's kind list in the same change.

## Build the page

After the page is written, and again after every later edit of it, embed the brand and status styles and render the diagrams:

```powershell
pwsh <an-dr-convention-html-report>/scripts/embed-brand.ps1 -Path <page>.html
if ($LASTEXITCODE -ne 0) { throw 'Brand embedding failed.' }
pwsh <an-dr-convention-html-report>/scripts/embed-cockpit.ps1 -Path <page>.html
if ($LASTEXITCODE -ne 0) { throw 'Status stylesheet embedding failed.' }
pwsh <an-dr-convention-html-report>/scripts/render-mermaid.ps1 -Path <page>.html
if ($LASTEXITCODE -ne 0) { throw 'Diagram rendering failed.' }
```

Check each exit code before continuing; a later success must not hide an earlier failure. `render-mermaid.ps1` needs a local Chrome or Edge, or `-Browser <exe>`, and stops on a diagram that fails to parse, leaving the page unchanged. To change a diagram, edit its stored source or write a new `<pre class="mermaid">` block, then build again.

## Verify

After the final build, capture and open screenshots of the actual page in light and dark themes at desktop width and at a 390 CSS-pixel phone viewport, and inspect text, tables, diagrams, and controls in all four views. Saving an image, parsing HTML, or measuring overflow is not an inspection.

Check the browser's actual viewport width: a narrow headless Chrome window can keep a wider viewport and crop its screenshot. Use device emulation or a fixed-width 390-pixel iframe inside a wider window, and record the inner viewport and document widths.

Keep a visual-check record with the report: final HTML hash, screenshot paths, theme and viewport of each view, which screenshots were opened, and the issues seen. Verification is complete only when all four views were inspected and no layout defect remains. Without a browser or image viewer, deliver the report with visual verification marked blocked and name the missing check; the renderer's success or a later reviewer's look does not replace it.

## Publish

Once the artifact is complete:

```powershell
pwsh <an-dr-convention-artifact-layout>/scripts/publish-latest.ps1 -Path <artifact-file>
```

It replaces every `<kind>-latest.*` file with copies of all files sharing the artifact's stamp, and prints the copies.

## Output

The stamped path and the latest path, both reported to the user, with the visual-check result: complete, or blocked and why.

## Rules

- Never build an artifact path by hand, in prose or in a script.
- Never load Mermaid or any other script, style, or font from the network.
