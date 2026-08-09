---
name: git-commit
description: Compose and record a commit in the repository's unified Conventional Commits format — subject shape, bullet body, footers, and the pre-commit checks. Use whenever work is ready to commit, including the workflow COMMIT phase.
allowed-tools: PowerShell
---

# Commit

This skill owns the commit message format. `git-commit-fix` rewrites existing history to the same specification and validates against the same module, so the rules live here and nowhere else.

The base is [Conventional Commits](https://www.conventionalcommits.org/en/about/). Only the rules below narrow it; anything the spec allows and this file does not mention stays as the spec defines it.

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
- Scope is required when the change is confined to one component, and omitted when the change is genuinely cross-cutting. Use only a scope listed under `## Commit scopes` in the host's root `AGENTS.md`, which `agents-integration` creates during onboarding; the checker rejects anything else. Add a scope to that list before using it, never per commit.
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
- Never add AI attribution or co-author trailers.

## Procedure

1. Run `git log --oneline -6`. Squash tip-only WIP commits on the same concern into one clean commit before adding another.
2. Review the staged diff. If it carries more than one concern, split it.
3. Compose, check, and record the commit in one call:

```powershell
pwsh agents/skills/git-commit/scripts/new-commit.ps1 `
    -Type fix -Scope ci `
    -Summary 'comma-separate cargo install --features on win-arm64' `
    'cargo took only env_logger from --features, making structopt a package' `
    'shell:true joins argv with unquoted spaces, splitting the value in two'
```

Body entries are the trailing arguments, one quoted string each, written without the `- ` marker. The script assembles the subject, prefixes the entries, appends `-Footer` lines after the single blank line, and commits only when every rule passes; otherwise it prints the violations and commits nothing. `-Breaking` adds `!` and requires a `BREAKING CHANGE:` footer. `-DryRun` prints the message, `-Amend` rewrites the tip.

To validate a message that already exists — a file, a string, or a commit — use the checker, which also works as a `commit-msg` hook:

```powershell
pwsh agents/skills/git-commit/scripts/check-message.ps1 -Path <file>
pwsh agents/skills/git-commit/scripts/check-message.ps1 -Commit HEAD
```

Both exit non-zero on any violation and print entry-length warnings without failing. Committing never authorizes pushing.

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
