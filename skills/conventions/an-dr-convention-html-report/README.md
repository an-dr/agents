# an-dr-convention-html-report

How every human-facing HTML page in this repository is built: one self-contained file, the shared brand, a theme switch, a print layout, problem levels, and diagrams rendered offline.

## When it runs

A convention is read, never run. Any skill that writes an HTML page for people uses it — reviews, change reports, overviews — and runs its three scripts to finish the page.

## How it works

```mermaid
flowchart LR
  W[Page written by a skill] --> B[embed-brand.ps1: brand stylesheet + theme switch]
  B --> K[embed-cockpit.ps1: problem-level styles]
  K --> M[render-mermaid.ps1: light + dark SVG per diagram, offline]
  M --> V[Visual check: light and dark, desktop and 390 px phone]
```

- **Self-contained.** Inline CSS and scripts, nothing from the network; the page looks the same from disk, a preview, or a published link.
- **Brand.** Every colour and font comes from one stylesheet; pages define none of their own.
- **Levels.** A page that reports problems uses the dark-cockpit levels and no other status colour.
- **Diagrams.** Mermaid renders in local headless Chrome or Edge; the page stores the source, with a "Copy Mermaid" button.
- **Verified** means screenshots in both themes at desktop and phone width were opened and inspected; otherwise the page is reported as unverified.

## What you get

Reports that work offline, print cleanly, respect your theme, and put problems where the eye lands.

## Related skills

- [an-dr-files-build-report](../../actions/an-dr-files-build-report/README.md) — runs the build steps.
- [an-dr-concept-dark-cockpit](../../concepts/an-dr-concept-dark-cockpit/README.md) — the level meanings.
- [an-dr-convention-artifact-layout](../an-dr-convention-artifact-layout/README.md) — where pages are saved.
