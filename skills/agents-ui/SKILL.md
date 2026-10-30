---
name: agents-ui
description: Talk to the user in a form that works in every host — terminal CLIs, GUI apps, and the Claude and Codex editor extensions — using the host's own question UI wherever it exists and a fixed text form only where it does not, with readable tables, questions with options, confirmations, and one answer format the agent reads the same way everywhere. Use whenever a reply shows a table, relays a script's output, asks the user to choose or confirm, or reads the user's answer to such a question.
---

# Agents UI

Hosts differ: some give the agent a clickable question widget, others show only text, and each renders a different subset of Markdown. Use the richest UI the host offers, fall back to text only when it offers none, and read every answer into the same decision, so a click and a typed reply mean the same thing.

## Choosing the channel

1. **Native UI first.** When the host gives the agent a question tool, every question, choice, and confirmation goes through it: Claude Code's `AskUserQuestion`, Codex's `request_user_input`, or the equivalent in another tool. Check the tools available in this session; do not assume them from the host's name.
2. **Text fallback.** Only when no such tool exists — or it fails, or the session is non-interactive — write the question in the text form below.
3. **Never both.** Do not repeat a question in chat that is already shown in a widget.

## Safe Markdown

Use only: paragraphs, `#`–`###` headings, bold, inline code, fenced code blocks, bullet and numbered lists one level deep, and pipe tables. Do not use HTML tags, lists nested more than one level, footnotes, task-list checkboxes, Mermaid in chat, or emoji that carry meaning. Status glyphs come from `ui-dark-cockpit`.

## Tables

- Use a table when rows share at least two attributes the reader compares; otherwise use a list.
- Keep a table to at most 5 columns and about 80 characters per row, so it does not wrap in an 80-column terminal. Put long text in a numbered note under the table and point to it from the cell: `see 2`.
- Give the first column a short key the reader can quote back: `1`, `A`, a file name.
- Keep each cell to one line: no line breaks, no lists, and write `\|` for a literal pipe. Right-align numbers with `---:`.
- Order rows by what the reader acts on first; for findings, that is `ui-dark-cockpit`'s ladder.
- Past about 15 rows, show the rows that matter, and say how many were left out and where the full list is.

## Script output

The user does not see tool results: hosts collapse them, cut them short, or hide them. A script's output reaches the user only through the agent's reply.

- **Relay what the user would act on.** When a skill script prints a result, such as a table, a status, a report path, a set of findings, or a failure, put it in the reply. The script having printed it does not count as the user having seen it.
- **Present it, don't paste it.** Rewrite the output in the safe Markdown above: tables follow the table rules, findings follow `ui-dark-cockpit`, and file paths become clickable links where the host supports them. Keep a Markdown table the script already shaped for the user as it is. Wrap raw text whose layout carries meaning, such as a diff or an error trace, in a fenced block.
- **Keep every fact, drop the noise.** Show every row and number a decision depends on. Leave out progress lines, banners, and repeated boilerplate, and say when you shortened something long.
- **Failures in full.** A non-zero exit is always reported, with the message that explains it, even when you go on to fix it.

## Questions

Ask only what blocks the work or what the user must decide; settle the rest with a stated default. Collect the open questions and ask them together, at most 4 at a time, then continue independent work while waiting.

Every question, in any channel, has:
- a self-contained question, readable without the earlier conversation;
- 2–4 options, each a short label plus its consequence;
- the recommended option first, marked `(Recommended)`, and only when a recommendation exists;
- no "Other" option, because free text is always accepted.

The text form, used only as the fallback:

```text
**Q1. Which storage should the cache use?**
  a. SQLite file (Recommended) — survives restarts, one extra dependency
  b. In-memory map — fastest, lost on restart
  c. Redis — shared across processes, needs a running server

**Q2. Which events refresh the cache?** (choose any)
  a. File change
  b. Timer
  c. Manual command

Answer like `1a 2bc`, or write your own text for any question: `2: only on Mondays`.
```

Number questions `Q1`, `Q2`, …; letter options `a`, `b`, …. Keys never change within one round, so an answer always points at exactly one option.

## Confirmations and yes/no questions

A confirmation is a question with exactly two options, never an open "OK?" or "Shall I proceed?" at the end of a message.

- **Name the action.** Say what happens on yes, and what is affected: "Delete the 3 files in `build/`?", not "Continue?".
- **Name both outcomes.** Each option states its consequence: `Yes — delete them` and `No — keep them and stop`.
- **Default to the safe side.** For a destructive, outward-facing, or hard-to-undo action, put the safe option first and mark no recommendation. For a routine step, the recommended option goes first.
- **One action per confirmation.** Do not bundle "commit and push" into one yes; ask two questions in the same round.
- In the native UI, it is a single-select question with those two options. In text, write it as one question with `a. Yes — …` and `b. No — …`, and also accept `y`, `yes`, `n`, `no`.
- Silence, a change of topic, or general enthusiasm is not a yes. The action waits until it gets an explicit yes.

## Answers

Read every reply the same way, whether it came from a widget or as text. In text, accept every form the user plausibly writes, in any order and with any separator: `1a 2b`, `1a, 2b`, `a b` in question order, `1: a`, `Q2 b`, `1ac` for multi-select, an option's label, `y`/`n` for a confirmation, or free text after `N:`. A reply to a round with only one question needs no number.

Before acting, repeat back each decision you read, one line per question:

```text
Q1 → a. SQLite file
Q2 → custom: only on Mondays
```

Skip the repeat when the native UI already showed the chosen labels and there was no free text.

- An unanswered question stays open; never fill it in with the recommendation. Proceed with what was answered and list what is still open.
- When an answer is ambiguous — a letter that does not exist, two options for a single-select question, or text that fits more than one option — ask that question again, alone, with the same keys.
- When free text changes the premise of a question, treat it as new information: restate the affected options and ask again rather than forcing the text into one of them.

## Answers as JSON

When a decision must outlive the conversation, or another script or agent acts on it, keep the round as JSON in the `ui` directory `artifact-storage` gives you. Write the round to `questions.json` before asking:

```json
{ "questions": [
  { "id": "Q1", "question": "Which storage should the cache use?",
    "options": [ { "label": "SQLite file (Recommended)", "description": "survives restarts" },
                 { "label": "In-memory map" } ] },
  { "id": "Q2", "question": "Delete the 3 files in build/?", "kind": "confirm",
    "options": [ { "label": "No — keep them" }, { "label": "Yes — delete them" } ] }
] }
```

Options take the keys `a`, `b`, … in order unless they set `key`. `multiSelect: true` allows several choices. `kind: "confirm"` also accepts `y`/`n`. Then pass the reply through the reader. A typed reply goes in as typed. A native widget's result goes in as `N: <chosen label>` per question.

```powershell
pwsh <skill>/scripts/read-answers.ps1 -Questions <dir>/questions.json -Reply '1a 2: only on Mondays'
```

It writes `answers.json` beside the questions file and prints the echo lines. Each answer has a `status`: `answered` with `choices` and `labels`, `custom` with `text`, `ambiguous` (ask again), or `open`. Act only on `answered` and `custom` answers.
