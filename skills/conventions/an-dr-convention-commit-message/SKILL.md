---
name: an-dr-convention-commit-message
description: The repository's commit message format — Conventional Commits narrowed to a typed subject, a one-line-per-entry bullet body, footers, no Markdown, and no AI attribution. Use when composing, reviewing, or rewriting any commit message; check-message.ps1 in this skill enforces it.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: convention
  an-dr.dependencies: PROHIBITED
---

# Convention: commit message

Base: [Conventional Commits](https://www.conventionalcommits.org/en/about/); anything not narrowed here stays as the spec defines it.

## Format

```text
type(scope)!: imperative summary

- first point
- second point

BREAKING CHANGE: what breaks
```

## Subject

- `type(scope)!: summary`; `!` marks a breaking change.
- Type: `feat`, `fix`, `docs`, `refactor`, `test`, `style`, `chore`, `build`, `ci`, `perf`, `revert`, nothing else. Two types means two commits.
- Scope required when the change is confined to one component, omitted when genuinely cross-cutting.
- Only scopes listed under `## Commit scopes` in the host's root `AGENTS.md`; a new scope is added to that list first, never per commit.
- Imperative mood, lowercase first word, no trailing period, at most 72 characters including type and scope.
- A `fix` subject may state the symptom when the bug is the point: `fix(webview): dragging a row selects the text under it`.

## Body

- Omitted when it would only restate the subject; otherwise one to five `- ` entries.
- One line per entry, never wrapped, near 72 characters.
- Each entry starts with a letter, preferably the verb; a leading `-`, `--`, `.`, `*`, `#`, or digit and period reads as Markdown, so it is rephrased, not escaped: `cargo took only env_logger from --features`, not `--features took only …`.
- Lowercase, no trailing period.
- No blank lines between entries; the single blank line means footers follow, which is how the spec and `git interpret-trailers` find them.
- Cause or motivation; the diff shows what changed.
- Only what the commit does or was observed to do; untested behaviour is described as added: `adds CI that builds three platforms`, not `built in CI for three platforms` before CI ran.

## Markdown

- None: `git log` and GitHub show messages preformatted, so backticks, bold, headers, and links appear literally and spend length.
- Identifiers go bare.
- The `- ` marker is the one exception.

## Footers

- Separated from the body by the message's only blank line.
- `BREAKING CHANGE: <consequence>` whenever the subject carries `!`.

## Attribution

The person who ran the commit is its author; a trailer records accountability, and the tooling is no more a co-author than the editor or compiler. No AI tool is named as author, co-author, assistant, or generator anywhere in the message:

- no `Co-Authored-By:`, `Co-Developed-By:`, `Assisted-By:`, `Authored-By:`, `Generated-By:`, or `Created-By:` trailer, whoever it credits;
- no "generated with", "written by", or "created by" line naming a model, agent, or assistant, and no robot emoji marker;
- no tool address such as `noreply@anthropic.com`.

The checker rejects these on every line, whether from `-Footer`, a body entry, or `-Amend`. A tool as the subject of the work is allowed: `feat(install): link the skills into the Claude Code directory`.

## Check

`scripts/check-message.ps1` verifies a message file, string, or commit against these rules, including the scope list, and works as a `commit-msg` hook; it is the only enforcement point for every tool that records, rewrites, or validates a message. It exits non-zero on any violation and prints entry-length warnings without failing.

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
