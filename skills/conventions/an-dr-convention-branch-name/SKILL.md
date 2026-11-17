---
name: an-dr-convention-branch-name
description: How a work branch is named — the host repository's own branch style when its history shows one, otherwise Conventional Branch, a type prefix and a lowercase hyphenated description. Use when creating, naming, or reviewing a branch.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: convention
  an-dr.dependencies: PROHIBITED
---

# Convention: branch name

## Precedence

- The host repository's own style wins when its branches show a clear one: the prefixes, separators, and ticket format its existing branches share, or a naming rule in its contributing documents.
- Otherwise [Conventional Branch](https://conventionalbranch.org/) applies; anything not narrowed here stays as that specification defines it.

## Conventional Branch

```text
<type>/<description>
```

- Type: `feature` (or `feat`), `bugfix` (or `fix`), `hotfix`, `release`, `chore`, nothing else; the type says what the work is, not which flow or tool made it.
- Description: lowercase letters, digits, and hyphens between words; dots only between letters or digits, as in a version.
- No consecutive, leading, or trailing hyphen or dot, and no hyphen next to a dot.
- No uppercase, underscore, space, or other character.
- Short and descriptive; a ticket number, when one exists, in lowercase: `feature/issue-123-new-login`.
- The trunk branches `main`, `master`, and `develop` take no prefix.

## Examples

```text
feature/add-login-page
fix/header-bug
release/v1.2.0
chore/upgrade-node-v20.11
```
