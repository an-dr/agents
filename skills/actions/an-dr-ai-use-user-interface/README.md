# an-dr-ai-use-user-interface

How the agent talks to you in any tool: questions through the host's own question UI when it has one, a fixed text form when it does not, an experimental browser page with a live progress log and forms only when you ask for it, and script output relayed so you never miss a result.

## When it runs

Whenever a reply shows a table, relays script output, asks you to choose or confirm, or reads your answer — in every flow and every skill.

## How it works

```mermaid
flowchart TD
  Q[Something to ask or show] --> T{Session has a question tool?}
  T -- yes --> W[Widget: 2–4 options, recommended first]
  T -- no, or it fails --> X[Text form with numbered options]
  T -- you ask for the page --> F[Experimental page: progress log and forms]
  F -- no browser, timeout, no Python --> X
  S[Script output] --> M{user-output marker}
  M -- verbatim --> V[Shown exactly as printed]
  M -- summarize --> U[Condensed, every fact kept]
```

- **Questions** are asked only when they block the work or the decision is yours. Up to four per round, each readable on its own, each option naming its consequence. Free text is always accepted.
- **Confirmations** are a question with exactly two options that name the action: "Delete the 3 files in `build/`?" rather than "Continue?".
- **Browser page** is experimental, off by default, and used only when you ask for it. One page on `127.0.0.1` behind a one-time token has two columns: the forms you answer and send with Commit on the left, with your earlier answers below them, and a progress log the agent updates at every step on the right. The address stays the same for the chat, and nothing is cleared when the agent stops and restarts the page. Your changes are saved as you go, and the page is kept as a read-only record in `tmp-ai-ui.html`, which git ignores. It needs Python 3 and a host that can run a background command — this skill's one intentional exception to the PowerShell rule.
- **Script output** never stays hidden in a tool result: tables, report paths, failures, and non-zero exits always reach the reply.

## What you get

Questions you can answer with one click, and every result a script produced, in Markdown that renders in any terminal or chat.

## What you decide

Every question it asks; a click and a typed reply count the same.

## Related skills

- [an-dr-concept-dark-cockpit](../../concepts/an-dr-concept-dark-cockpit/README.md) — levels for findings in replies.
- [an-dr-convention-script](../../conventions/an-dr-convention-script/README.md) — how scripts mark their output.
