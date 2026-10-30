---
name: an-dr-convention-commit-message
description: The repository's commit message format — Conventional Commits narrowed to a typed subject, a one-line-per-entry bullet body, footers, no Markdown, and no AI attribution. Use when composing, reviewing, or rewriting any commit message; check-message.ps1 in this skill enforces it.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: convention
  an-dr.dependencies: PROHIBITED
---

# Convention: commit message

The base is [Conventional Commits](https://www.conventionalcommits.org/en/about/). Only the rules below narrow it; anything the spec allows and this file does not mention stays as the spec defines it. `check-message.ps1` in this skill enforces the format for every tool that records, rewrites, or validates a commit message, so the rules live here and nowhere else.

## Format

```text
type(scope)!: imperative summary

- first point
- second point

BREAKING CHANGE: what breaks
```

## Subject

- `type(scope)!: summary`, where `!` marks a breaking change.
- Type is one of `feat`, `fix`, `docs`, `refactor`, `test`, `style`, `chore`, `build`, `ci`, `perf`, `revert`. Nothing else. Needing two types means the commit does two things and must be split.
- Scope is required when the change is confined to one component, and omitted when the change is genuinely cross-cutting. Use only a scope listed under `## Commit scopes` in the host's root `AGENTS.md`; the checker rejects anything else. Add a scope to that list before using it, never per commit.
- Imperative mood, lowercase first word, no trailing period, 72 characters or fewer including the type and scope.
- A `fix` subject may state the symptom instead of the action when the bug is the point: `fix(webview): dragging a row selects the text under it`.

## Body

- Omit the body when it would only restate the subject.
- Otherwise one to five entries, each a `- ` line.
- One line per entry. Never wrap an entry; keep it near 72 characters so it fits a terminal line instead.
- Every entry starts with a letter, preferably the verb. Leading `-`, `--`, `.`, `*`, `#`, or a digit and period collides with the list marker or reads as Markdown, so rephrase rather than escape: write `cargo took only env_logger from --features`, not `--features took only …`.
- Lowercase, no trailing period.
- No blank lines between entries. The single blank line in a message means "footers follow", which is how the spec and `git interpret-trailers` find them.
- Explain cause or motivation. The diff already shows what changed.

## Markdown

None. `git log` and GitHub's commit view render messages as preformatted text, so backticks, bold, headers, and links appear literally to every reader and spend the entry's length budget. Identifiers go bare — the sentence around them is enough context. The `- ` marker is plain text that happens to also be valid Markdown, which is why it is the one exception.

## Footers

- Separated from the body by the message's only blank line.
- `BREAKING CHANGE: <consequence>` whenever the subject carries `!`.

## Attribution

The commit is authored by the person who ran it. An AI tool that helped write the change is never named as an author, co-author, assistant, or generator — not in a trailer, not in the body, not in the subject.

- No `Co-Authored-By:`, `Co-Developed-By:`, `Assisted-By:`, `Authored-By:`, `Generated-By:`, or `Created-By:` trailer, whoever it credits.
- No "generated with", "written by", or "created by" line naming a model, agent, or assistant, and no robot emoji marker.
- No tool address such as `noreply@anthropic.com`.

The checker rejects all of it, on every line of the message and whether it arrives through `-Footer`, a body entry, or `-Amend`. Naming a tool as the *subject of the work* stays allowed, because that is what the change is about: `feat(install): link the skills into the Claude Code directory` is fine.

The reason is that a trailer is a record of who is accountable for the change. That is the author, who reviewed the diff and chose to record it; the tooling used to produce it is no more a co-author than the editor or the compiler, and crediting it dilutes the one signal `git log`, `git blame`, and release notes read.

## Check

```powershell
pwsh <skill>/scripts/check-message.ps1 -Path <file>
pwsh <skill>/scripts/check-message.ps1 -Commit HEAD
```

The checker validates a message file, a string, or a commit, and also works as a `commit-msg` hook. It exits non-zero on any violation and prints entry-length warnings without failing.

## Examples

```text
fix(ci): comma-separate cargo install --features on win-arm64

- cargo took only env_logger from --features, making structopt a package
- shell:true joins argv with unquoted spaces, splitting the value in two
- a comma-separated list stays one token
```

```text
fix(webview): raise the minimum window width to 1200
```

```text
feat(git)!: return typed errors from remoteOperation

- replace the boolean result with Result<(), RemoteError>
- map git exit codes to auth, network, and conflict variants
- branch on the variant instead of parsing stderr in callers

BREAKING CHANGE: remoteOperation returns Result instead of bool
```

```text
refactor: store the version marker through the shared persistence module

- drop the hand-rolled marker file written beside the executable
- reuse the module's atomic write, so a crash cannot truncate the marker
- keep the marker's on-disk name and location unchanged
```
