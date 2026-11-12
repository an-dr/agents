---
name: an-dr-ai-use-user-interface
description: Talk to the user in a form that works in every host, using the host question UI or a fixed text form, plus an experimental browser page on request. Use whenever a reply shows a table, relays script output, asks the user to choose or confirm, or reads their answer.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "2.2.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-concept-dark-cockpit an-dr-convention-html-repo-style an-dr-files-build-report
---

# User interface

Defers: severity levels to `an-dr-concept-dark-cockpit`, the look of its browser page to `an-dr-convention-html-repo-style`, artifact paths to `an-dr-files-build-report`.

## Choose the channel

- Session has a question tool (Claude Code `AskUserQuestion`, Codex `request_user_input`, or equivalent) → every question, choice, and confirmation goes through it. Check this session's tools; do not infer them from the host's name.
- No such tool, it fails, or the session is non-interactive → use the text form.
- The user asks for the browser form ("use the form", "ask me in the browser") → Ask in a form. Never choose it, offer it, or mention it otherwise: it is experimental and off by default.
- Never repeat in chat a question already shown in a widget.
- A click and a typed reply map to the same decision.

## Format text

For safe Markdown, tables, and rendering findings, read [references/text-format.md](references/text-format.md).

## Relay script output

The user does not see tool results; output reaches them only through the reply.

- Every `<!-- user-output: … -->` … `<!-- /user-output -->` block appears in the next reply, never deferred, without the markers: `verbatim` exactly as printed; `summarize` rewritten, keeping every fact.
- Relay every result the user would act on: tables, status, report paths, findings, failures.
- Rewrite in safe Markdown; paths as clickable links where supported; keep a Markdown table the script already shaped; fence raw text whose layout matters (diffs, traces).
- Keep every row and number a decision depends on; drop progress lines, banners, boilerplate; say when you shortened something.
- Always report a non-zero exit with its explaining message, even when you go on to fix it.

## Ask questions

- Ask only what blocks the work or what the user must decide; settle the rest with a stated default.
- Ask open questions together, at most 4 per round; continue independent work while waiting.
- Each question is self-contained, readable without earlier conversation.
- 2–4 options, each a short label plus its consequence.
- Recommended option first, marked `(Recommended)`, only when a recommendation exists.
- No "Other" option; free text is always accepted.
- For the text form, read [references/text-questions.md](references/text-questions.md).

## Confirm actions

- A confirmation is a question with exactly two options, never an open "OK?" or "Shall I proceed?".
- Name the action and what it affects: "Delete the 3 files in `build/`?", not "Continue?".
- Each option states its consequence: `Yes — delete them`, `No — keep them and stop`.
- Destructive, outward-facing, or hard-to-undo → safe option first, no recommendation; routine → recommended option first.
- One action per confirmation; "commit and push" is two questions in the same round.
- Native UI → single-select with the two options; text → `a. Yes — …` / `b. No — …`, also accepting `y`, `yes`, `n`, `no`.
- Silence, a topic change, or enthusiasm is not a yes; the action waits for an explicit yes.

## Read answers

- Read widget and text replies the same way.
- Before acting, echo each decision, one line per question; skip when the native UI showed the chosen labels and there was no free text.
- Unanswered → stays open, never filled with the recommendation; proceed with what was answered and list what is open.
- Ambiguous (nonexistent letter, two options on single-select, text fitting several options) → ask that question again, alone, same keys.
- Free text changing the question's premise → restate the affected options and ask again.

## Keep answers as JSON

When a decision must outlive the conversation or a script or agent acts on it, write the round before asking to a `ui` path with extension `questions.json`, taken through `an-dr-files-build-report`. For the schema, read [references/answers-json.md](references/answers-json.md). Pass the reply through the reader: a typed reply as typed, a widget result as `N: <chosen label>` per question.

```powershell
pwsh <skill>/scripts/read-answers.ps1 -Questions <ui-stamp>.questions.json -Reply '1a 2: only on Mondays'
```

Writes `<ui-stamp>.answers.json` beside the questions file and prints the echo lines. Each answer's `status`: `answered` (`choices`, `labels`), `custom` (`text`), `ambiguous` (ask again), or `open`. Act only on `answered` and `custom`.

## Ask in a form

An experimental channel for a browser page with a progress log and forms, used only when the user asks for it. It needs Python 3 and a host that can run a command in the background. Before using it, read [references/browser-page.md](references/browser-page.md).
