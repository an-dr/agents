# an-dr-convention-commit-message

The commit message format: Conventional Commits narrowed to a typed subject, a short bullet body, footers, no Markdown, and no AI attribution.

## When it runs

A convention is read, never run. Skills load it when composing, reviewing, or rewriting a commit message. `scripts/check-message.ps1` is the single enforcement point and also works as a `commit-msg` hook.

## How it works

```text
feat(install)!: link the skills into the tool's user directory
- the old copy step drifted from the clone after every pull
- links keep one source and update with git pull

BREAKING CHANGE: re-run the installer after upgrading
```

- **Subject:** a type from a fixed list, a scope from the host's `AGENTS.md` scope list, an imperative lowercase summary, at most 72 characters; `!` marks a breaking change.
- **Body:** optional, one to five `- ` entries, one line each, saying why rather than what. The diff already shows what.
- **No Markdown** apart from the `- ` marker, because `git log` shows it literally.
- **Footers** after the only blank line; `BREAKING CHANGE:` is required with `!`.
- **Attribution:** the person who ran the commit is its author. No AI co-author trailer, "generated with" line, or tool address — the checker rejects them.

## What you get

A history where every subject scans in one line, and every commit was checked by the same script, whichever tool made it.

## Related skills

- [an-dr-git-modify-history](../../actions/an-dr-git-modify-history/README.md) — records and rewrites commits with it.
