---
name: an-dr-ai-use-user-interface
description: Talk to the user in a form that works in every host, via the host's question UI, a local browser form, or else a fixed text form, for tables, questions, confirmations, and reading answers. Use whenever a reply shows a table, relays script output, asks the user to choose or confirm, or reads their answer.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "2.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-concept-dark-cockpit an-dr-files-build-report
---

# User interface

Defers: severity levels to `an-dr-concept-dark-cockpit`, artifact paths to `an-dr-files-build-report`.

## Choose the channel

- Session has a question tool (Claude Code `AskUserQuestion`, Codex `request_user_input`, or equivalent) → every question, choice, and confirmation goes through it. Check this session's tools; do not infer them from the host's name.
- No such tool, it fails, or the session is non-interactive → use the text form.
- A round the widget cannot carry well (more than 4 questions, long option texts, a table to read first) and a session that can open a browser → offer the browser form; see Ask in a form.
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

An optional channel for a large round. It needs Python 3 and a browser on the user's machine; `ask-form.py` is this repository's one intentional Python script, an exception to its PowerShell-only script rule.

1. Write the round as a `questions.json` file, as in Keep answers as JSON.
2. Run it; the page opens in the browser and the call blocks until the user sends the answers:

```shell
python <skill>/scripts/ask-form.py --questions <ui-stamp>.questions.json
```

3. Exit `0` → answers are in `<ui-stamp>.answers.json`, the same file `read-answers.ps1` writes; echo each decision and act on `answered` and `custom` only.
4. Exit `3` (no browser here) or `4` (no answer within 9 minutes), or no Python → ask the same round in the text form; never leave it open.
5. Exit `2` → the questions file is invalid; fix it.

The form is a channel, not a second source of decisions: an approval the workflow requires still goes through the controller in the user's own words. Do not repeat in chat a round the form shows.
