# Browser page

An experimental channel, used only when the user asks for it. It needs Python 3, a browser on the user's machine, and a host that can run a command in the background; `ai-ui.py` is this repository's one intentional Python script, an exception to its PowerShell-only script rule. One page has two columns: Interaction on the left (the forms the user answers, then the earlier answers) and Progress on the right (the log the user watches).

1. Pick one `<state>` prefix per chat from `an-dr-files-build-report` (kind `ui`) and reuse it for the whole chat; every file below is `<state>.<kind>.json`. Start the server in the background, and tell the user the page is open. The address is stable for the chat, and the log, the answered rounds, and the draft persist across `stop` and `serve`, so running `serve` again is safe: it reuses a running server, and an open tab reconnects by itself:

```shell
python <skill>/scripts/ai-ui.py serve --state <state>
```

2. At each step of the work, run `python <skill>/scripts/ai-ui.py log --state <state> "what is happening"` (`--status done` or `--status problem` when it fits), one short line, so the user always sees what is happening. Never read the page back.
3. To ask, write `<state>.questions.json` (schema in Keep answers as JSON); writing a new one replaces the forms, and the answered round moves to the user's earlier answers. Then run `python <skill>/scripts/ai-ui.py wait --state <state>`, in the background where the host notifies on exit. It blocks, costs no tokens, and ends when the user presses Commit.
4. Exit `0` → the echo lines are the decisions, also in `<state>.answers.json`, the same file `read-answers.ps1` writes; act on `answered` and `custom` only. Exit `4` (no Commit within 9 minutes) → ask the same round in the text form, or wait again; the draft is kept. Exit `2` → the questions file is invalid; fix it. `serve` exit `3` (no browser here), or no Python → use the text form; never leave a question open.
5. At the end, run `python <skill>/scripts/ai-ui.py stop --state <state>`. The page is saved as a read-only record to `tmp-ai-ui.html` in the working directory and added to `.git/info/exclude`, so it never shows in a diff; the server also stops by itself after an hour.

The page is a channel, not a second source of decisions: an approval the workflow requires still goes through the controller in the user's own words. Do not repeat in chat a round the page shows.
