---
name: dev-change-report
description: Produce one human-facing HTML report of a finished change — what was done and why, the responsibility of every new block, rendered Mermaid dependency graphs, a section per new and per upgraded component, decisions, and verification — explained with diagrams and plain prose rather than code. Use at the end of a big change, or when the user accepts the offer at the end of a smaller one.
---

# Change report

One HTML page that lets a reader who did not watch the work understand what changed, why, and how the parts now fit. It explains a change; `dev-project-overview` explains a whole repository.

Use `docs-writing` for the prose. The report describes work already delivered; it edits nothing in the repository.

## When

- **Write it** at the end of a big change: a Detailed or Detailed Auto flow, or any delivery that adds a component (crate, package, module, service), adds an ADR, or changes the architecture.
- **Offer it** in one line at the end of every other code delivery. Write it only when the user accepts.

## Gather first

Read the delivered diff, the commits, the intake requests or brief the work answered, the ADRs and architecture docs it touched, and the verification actually run. Every statement on the page comes from that evidence. Do not report a test, a measurement, or a behaviour that was not observed; list it under what was not verified instead.

## Sections, in order

1. **Summary** — what changed and why, in a few sentences, plus the rules or constraints that shaped the choices. Name the commits, versions, or tags the report covers.
1. **Requests** — each requested item with its status: done, partial, not done, with the reason.
1. **Architecture** — the layers or boundaries the change works within, as a diagram.
1. **Dependency graph** — every affected component and its edges after the change, with new, changed, and unchanged components visually distinct and a legend.
1. **New blocks** — one section per new component: its responsibility in one sentence, why it sits where it does, a flow or sequence diagram of how it works, its consumers, and its public interface only when the reader needs it.
1. **Upgraded blocks** — one section per existing component that changed: what it did before, what it does now, and why.
1. **Decisions** — every choice the plan left open or the work departed from, with the reason.
1. **Verification** — what was checked and the result, what was not verified, and known limitations.
1. **Open items** — follow-up work and the next commands, such as a push still waiting.

Omit a section only when it would be empty, and say so in the summary.

## Explain with diagrams, not code

- Draw structure and flow as Mermaid: `flowchart` for layers and dependencies, `sequenceDiagram` for handshakes and request flows, decision flowcharts for branching behaviour.
- Write every diagram as a `<pre class="mermaid">` block. The skill ships a pinned Mermaid build that `scripts/embed-mermaid.ps1` inlines into the page, so the diagrams render offline, in an editor preview, and when published alike; never load Mermaid from a CDN.
- Prose is plain and short. Code appears only as interface signatures or the few lines an adopter must write; never paste implementation.

## Write and deliver

Write the page to `REPO/.artifacts/reports/<short-name>.html`. Make it self-contained, readable in light and dark themes, and usable at phone width. Then embed the renderer, and run it again after every later edit of the page:

```powershell
pwsh <skill>/scripts/embed-mermaid.ps1 -Path REPO/.artifacts/reports/<short-name>.html
```

The script is idempotent and reports how many diagrams the page holds. When the tool can publish pages, publish it and give the user the link; otherwise name the file path. Tell the user when the page is private to them.
