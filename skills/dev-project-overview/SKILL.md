---
name: dev-project-overview
description: Produce a single self-contained HTML overview of an unfamiliar repository — what it is, C4 levels 1 to 3 drawn from the code, a reading path, the drift between what the documentation claims and what the code does, and a ranked list of the project's real structural problems. Use when arriving at a codebase, onboarding someone onto it, or auditing its architecture and health.
allowed-tools: Read, Grep, Glob, Write, Edit, Bash, PowerShell
---

# Project overview

One HTML page that takes a competent stranger from nothing to productive, and tells them the truth about the codebase they just inherited.

Use `docs-writing` for the prose. The page reports; it never fixes. Nothing in the scanned repository is edited.

## Code is the authority, documentation is intent

The README, the architecture guide, the ADRs, and the comments state what someone once intended. The code states what runs. When they disagree the code wins, and the disagreement is itself a finding worth the reader's attention — it is usually where the next bug comes from.

So documentation is read as a hypothesis and then tested against the code. Never resolve a contradiction silently, never repeat a documented claim the code does not support, and never quietly drop a documented component because it could not be found — record all three as drift.

Every statement on the page carries its provenance, and the page renders it as a badge:

| Badge | Means | Allowed source |
| --- | --- | --- |
| verified | Read in the code, with a path that exists | source files, manifests, CI definitions, lockfiles |
| inferred | A strong pattern the code implies but does not state | naming, directory shape, import graph, framework convention |
| claimed | Asserted by documentation and not confirmed | README, `docs/`, ADRs, comments, commit messages |

An inferred claim is never presented as verified, and a claimed one is never presented at all outside the drift table unless the reader is told it is unconfirmed.

## Gather the evidence first

Run the scan before reading anything, so the reading is aimed:

```powershell
pwsh <skill>/scripts/scan-project.ps1 [-Path <repo>] [-Json <file>]
```

It reports the languages and their weight, the manifests, entry points, container signals and packaging signals, the test ratio, the CI definitions, every documentation file with the age of its last edit against the repository's own last commit, the churn hotspots of the last year, the largest files, the `TODO`/`FIXME` density, and the author spread. The stale-document list and the churn list are where drift and risk are found; start there.

Then read, in this order: the manifests, the entry points, the configuration and its defaults, the module the churn list puts first, the tests of the primary flow, and only afterwards the prose documentation.

## The C4 levels

Draw levels 1 to 3. Level 4 is the code itself and the reader already has it.

| Level | Answers | Derived from |
| --- | --- | --- |
| 1 — Context | What is this system, who uses it, what does it talk to that it does not own | outbound calls, SDK and client dependencies, credentials and endpoints in configuration, webhooks, schedulers |
| 2 — Container | What separately runs or deploys, in what language, talking over what | entry points, `Dockerfile` and compose files, deployment manifests, CI jobs, process definitions, workspace members, ports and queues |

A desktop application, a CLI, or a library deploys nothing, and its container level is not empty — it is the declared binaries, the compiled guest artifacts, the packaging scripts, and the helper processes the main one spawns. The scan reports those separately for that reason.
| 3 — Component | Inside the container the reader will actually work in, what are the major groupings and how do they depend on each other | directory structure confirmed by the import graph, not by the directory names alone |

Draw only what the code confirms. A container the documentation describes but the repository does not contain is a drift row, not a box. A box drawn from an inferred grouping is labelled inferred.

Choose the level 3 container by where the work happens — the one with the most churn — and say why it was chosen. One component diagram is usually enough; a second is worth it only when the reader will genuinely work in both.

## The problems section

This is the part a newcomer cannot produce for themselves and the part the project's own documentation will never contain. Hunt for it deliberately rather than reporting whatever the scan happened to surface.

| Problem | Evidence that proves it |
| --- | --- |
| Circular dependencies | a concrete import cycle, named module by module |
| Layering violation | an inner layer importing an outer one — domain reaching into transport, business logic importing the database driver, UI holding SQL |
| God module | one file or class with disproportionate size and fan-in, named with both numbers |
| Duplicated logic | the same rule implemented in two places that can now disagree |
| Hidden coupling | modules that always change together in the churn history without importing each other |
| Dead code | exports, flags, or whole directories nothing reaches |
| Untested critical path | the primary flow's modules absent from the test evidence |
| Silent failure | swallowed exceptions, ignored return values, bare catches on the main path |
| Configuration and secrets | committed credentials, hardcoded hosts, defaults that only work on one machine |
| Dependency risk | unpinned, duplicated, abandoned, or a lockfile that disagrees with its manifest |
| Build and CI gaps | a build or test command in the documentation that CI does not run, or that fails on a clean checkout |
| Documentation drift | the whole intent-versus-reality table, summarised as one ranked entry |

Each finding needs a severity, a path that exists, what it costs the reader in practice, and the cheapest honest fix. Rank by cost and cut below the top ten — an unranked list of thirty reads as noise and gets ignored entirely. Symptoms are grouped under their cause; the same architectural fault listed eleven times is one finding.

Say plainly when a category came up clean. "No import cycles found" is information; silence is not.

## The page

Self-contained HTML, one file, opening correctly from disk with no network access. Diagrams are inline SVG — theme-aware through the same CSS variables as the rest of the page, with wide ones inside their own scrolling container. When the page is published as an Artifact instead, mermaid blocks render natively and may be used there.

Start from `assets/overview-template.html`, which carries the structure, the provenance badges, the severity chips, and a light and dark palette. Sections in this order:

1. **What this is** — three sentences, then the one thing to remember if the reader remembers nothing else.
2. **Facts** — languages, size, containers, test ratio, CI, licence, last activity, and the commit the page was generated from.
3. **Start here** — five files in reading order, each with one line on why it earns the reader's time.
4. **Context, container, component** — the three diagrams, each under a short paragraph that says what to notice.
5. **The main flow** — one primary use case traced end to end through the real call path.
6. **Repository map** — directory to purpose, marking what is generated, vendored, or dead.
7. **Glossary** — the domain terms as the code spells them, especially where the code and the documentation use different words for one thing.
8. **Intent versus reality** — what the documentation says, what the code does, the file that settles it, and the verdict.
9. **Problems and risks** — the ranked findings.
10. **Running it** — build, run, and test commands copied from the repository, each verified to exist.
11. **Open questions** — what could not be established, and what would settle it.

## Never fabricate

The failure mode of a generated overview is a confident, plausible, wrong architecture diagram, and it is worse than no overview because the reader will trust it for weeks.

- Every path, command, port, and environment variable on the page exists in the repository.
- A component that could not be found is absent from the diagram and present in the drift table.
- An unanswerable question goes to the open questions section. Three honest gaps beat three invented facts.
- The page is a snapshot, not a document under maintenance: stamp it with the commit and the date, and regenerate it rather than patching it.

## Output

Write to `.artifacts/overview/project-overview.html` in the scanned repository. Offer to publish it as an Artifact when the user wants a link rather than a file.

In the chat, report the count of drift rows and the top three problems with their severities, so the user learns the headline without opening the page.
