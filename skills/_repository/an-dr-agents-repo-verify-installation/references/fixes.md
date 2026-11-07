# Fixes by finding

| Finding                                                              | Fix                                                                                                                                             |
| -------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Install rows fail                                                    | Re-run `an-dr-agents-repo-install`'s `install-agents.ps1`; its SKILL.md owns conflicts, `unsupported` rows, and unknown tools                   |
| No root `AGENTS.md`/`CLAUDE.md`, or it does not reference the policy | Add a root instruction file referencing `agents/AGENTS.md`, only if the repository should be governed; the `verdict` row reports this as `info` |
| `AGENTS.md` without `CLAUDE.md`, or the reverse                      | Add the missing one; Claude Code reads `CLAUDE.md`; Codex, Copilot, opencode, and DeepSeek Harness read `AGENTS.md`                             |
| `agents/` present but empty                                          | `git submodule update --init --recursive`                                                                                                       |
| No `## Commit scopes` section                                        | Add one to the root `AGENTS.md`; `an-dr-convention-commit-message`'s checker rejects every scoped subject without it                            |
| Everything wired, policy not in context                              | Tool-side loading: oversized instruction file, unexpanded `@` import, cached session; restart, then reduce what the block loads                 |
| Everything wired and loaded, agent still skipped the flow            | Process defect, not installation: report it with the concrete task that went wrong                                                              |

The last row is this skill's boundary: a rule one tool follows and another ignores is evidence about wording, for a process proposal against `AGENTS.md` or a skill, which needs the concrete task from real work, not the observation alone.
