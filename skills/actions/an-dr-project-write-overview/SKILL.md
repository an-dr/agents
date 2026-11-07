---
name: an-dr-project-write-overview
description: Produce one self-contained HTML overview of an unfamiliar repository — what it is, C4 levels 1–3 from the code, a reading path, documentation-versus-code drift, and ranked structural problems. Use when arriving at a codebase, onboarding someone, or auditing its architecture and health.
license: MIT
allowed-tools: Read Grep Glob Write Edit Bash PowerShell
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-concept-ai-slop an-dr-files-build-report an-dr-convention-html-report an-dr-dev-write-documentation
---

# Project overview

Defers: prose to `an-dr-dev-write-documentation`; slop signals to `an-dr-concept-ai-slop`; page format to `an-dr-convention-html-report`; build, render, and publish to `an-dr-files-build-report`.

## Gather the evidence

1. Run the scan before reading anything:

   ```powershell
   pwsh <skill>/scripts/scan-project.ps1 [-Path <repo>] [-Json <file>]
   ```

   It reports languages and weight, manifests, entry points, container and packaging signals, test ratio and files with inline test modules, CI definitions, every documentation file with its last-edit age against the repository's last commit, last year's churn hotspots, largest files, `TODO`/`FIXME` density, and author spread. Start from the stale-document and churn lists; drift and risk are there.
2. Read in order: manifests, entry points, configuration and its defaults, the top churn module, tests of the primary flow, then prose documentation.
3. Treat documentation (README, architecture guide, ADRs, comments) as intent and a hypothesis; the code is what runs and wins. Record as drift every contradiction, every documented claim the code does not support, and every documented component not found; never resolve or drop one silently.
4. Tag every statement with provenance:

| Badge    | Means                                                | Allowed source                                              |
| -------- | ---------------------------------------------------- | ----------------------------------------------------------- |
| verified | Read in the code, with a path that exists            | source files, manifests, CI definitions, lockfiles          |
| inferred | A strong pattern the code implies but does not state | naming, directory shape, import graph, framework convention |
| claimed  | Asserted by documentation and not confirmed          | README, `docs/`, ADRs, comments, commit messages            |

- Inferred is never shown as verified; claimed appears only in the drift table unless marked unconfirmed.

## Draw C4 levels 1–3

For what each level derives from and how to pick the level 3 container, read [references/c4.md](references/c4.md).

## Hunt the problems

For the problem categories and their evidence, read [references/problems.md](references/problems.md).

- Each finding: severity, an existing path, its practical cost to the reader, the cheapest honest fix.
- Rank by cost; cut below the top ten. Group symptoms under their cause; one fault listed eleven times is one finding.
- State clean categories: "No import cycles found".

## Write the page

Before writing, read [references/page.md](references/page.md) for the template, levels, diagrams, and section order.

## Output

- Write at a `project-overview` path, extension `html`, in the scanned repository; build, verify, and publish through `an-dr-files-build-report`.
- Offer to publish as an Artifact when the user wants a link.
- In chat: the drift row count and the top three problems with severities.

## Rules

- Report only; edit nothing in the scanned repository.
- Every path, command, port, and environment variable on the page exists in the repository; a wrong confident diagram is worse than none.
- A component not found is absent from the diagram and present in the drift table.
- Unanswerable → open questions; never an invented fact.
- The page is a snapshot: stamp commit and date; regenerate, never patch.
