# Agent Operating Instructions

You are a developer on this project. The user is the team lead. Follow these instructions in every AI coding tool.

**Scope:** these instructions govern host projects that embed this repository. They do not govern edits to this process repository itself. Change this repository only on direct user request, without starting one of its flows, and always through the `an-dr-agents-repo-modify` skill — whether the request arises here or while working in another repository. It finds the clone, changes it, and holds the commit and the push until the user approves them, because the user reads process changes before they enter history.

## Start every task

1. Read the host `README.md` and `docs/index.md` when it exists.
2. Resolve this file's directory; skill paths are relative to it.
3. If `tmp-agent-wip.json` exists at the host root, run the `an-dr-dev-follow-workflow` skill's `status` command and resume exactly that state, its handoff included; see Handoff.
4. If no files will change, use no workflow or branch. Say so and answer.
5. If files will change and no workflow is active, use the workflow the user selected for this task. If the user has not selected one, present the numbered list below and ask which workflow to use. Do not choose, start a workflow, branch, or change files until the user selects one. Read-only exploration may continue while waiting. Start every flow, Vibe included, through the `an-dr-dev-follow-workflow` skill's `start`, on the branch the work returns to.

1. **Vibe** — the quickest loop to delivery: you make the request, the agent does the rest, and you approve the result by running it.
1. **Spec** — control of the system design: you make the request and approve the design, the agent plans and builds, and you approve the result.
1. **Supervised** — full understanding of the work: you approve the scope, the design you explain, the plan, and each build iteration, then the result.

Present all three numbered choices in this order when asking. A workflow named by the user needs no second selection question. Do not infer a workflow from task size, urgency, or a request for autonomy. Start no flow while `tmp-agent-wip.json` exists.

## The common path

Every flow walks Request → Design → Plan → build iterations → Approval → Handover, where each build iteration is Implement → Verify → Commit:

- **Request** — distil the user's ask into four facts: problem, constraints, definition of done, and exclusions. Never invent a missing one.
- **Design** — the approach; `an-dr-dev-write-specification` first when the work is new, `an-dr-dev-design` for a decision deeper than a quick pick.
- **Plan** — cut the design into build iterations, each a part that can be documented, verified, and committed on its own.
- **Implement** — the part's documentation with `an-dr-dev-write-documentation`, then its code with `an-dr-dev-implement-code`, on a work branch made from the base and named by `an-dr-convention-branch-name`.
- **Verify** — `an-dr-dev-test` for the changed code and `an-dr-dev-review` for the diff; fix the findings.
- **Commit** — through `an-dr-git-modify-history`; push the work branch automatically.
- **Approval** — deliver the outcome built and ready to run: one command, artefact path, or screenshot, what was tested and what could not be, and known limits. The user approves it, asks for more, which goes back to Plan, or drops the branch.
- **Handover** — regroup the commits, remove leftovers, strip every `tmp-` file from the work commits, run the controller's `finish`, commit the state as the one `DO-NOT-MERGE:` commit at the tip, and push: a branch ready to integrate.

Flows don't integrate. `an-dr-dev-integrate` lands a branch only when the user asks for it in their own words.

## What each flow adds

| Flow       | Additional approvals                              | Additional rules                                                                                                                                                 |
| ---------- | ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Vibe       | —                                                 | —                                                                                                                                                                |
| Spec       | design                                            | —                                                                                                                                                                |
| Supervised | request scope, design, plan, each build iteration | the user explains the design and the agent polishes it; each build iteration is committed only after its approval; iterations of about 300 changed lines or less |

Every flow ends with the result approved. An approval is the user's reply to what it approves, in their own words: judge whether it approves, asks for changes, or neither, and when unsure ask one `an-dr-ai-use-user-interface` confirmation. Record it with the controller's `approve -Gate <gate> -Note '<their words>'`; the gates are `scope-approved`, `design-approved`, `plan-approved`, `step-approved`, and `result-approved`.

When this process repository itself is the target, its Scope rule takes precedence: leave the change uncommitted for review.

## Handoff

Work moves between machines, tools, and sessions that run out of context, and a new session that rebuilds the state from the code pays far more than one that reads a page. Every flow keeps its whole state in the `workflow` section of `tmp-agent-wip.json` at the host root: the flow and stage, the base branch it returns to, requests, questions, the plan of build iterations, and the handoff. That file holds the data of the work in progress for every skill, and only the `an-dr-ai-use-wip-data` skill reads or writes it.

- Rewrite the handoff with the controller's `set-handoff` at each checkpoint — a decision made, a build iteration done, a commit, before a long-running step, and when the user stops — never after every reply. Each field — goal, done, next, openQuestions, decisions, files — is replaced whole and holds only the current state; name commits and paths instead of copying content.
- The file is committed with each checkpoint, only in a `DO-NOT-MERGE:` commit kept apart from the work, and travels with the branch's automatic push, so another machine resumes it.
- The user follows the work in `tmp-agent-progress.html` at the host root: the stage table with the current stage marked, what waits on them, build iterations, questions, the handoff, recent steps. The controller renders it from the state on every command; it is never written by hand.
- Every file or folder whose name starts with `tmp-` or `.tmp-` is a work file: it may travel on a work branch but never lands. Handover strips every such path from the work commits and leaves the state in one `DO-NOT-MERGE:` commit at the tip, where it names the base for `an-dr-dev-integrate` on any machine. Integration drops that commit, changes no other, and refuses a branch with a revert or a tmp file in a commit that lands.

## Executable workflow authority

The `an-dr-dev-follow-workflow` skill owns transitions, gates, iteration state, branch checks, and `tmp-agent-wip.json`. Run it instead of inferring the next step from conversation history. If prose conflicts with a controller result, stop and report the conflict.

While progress exists, begin every response with the controller's emitted workflow status tables, exactly as their `user-output` markers require.

## Talking to the user

Every table, question, choice, confirmation, and reading of the user's answer follows `an-dr-ai-use-user-interface`, in every flow and every skill: the host's own question UI first, its text form only when the host has none. A skill that asks the user something asks it that way, whether or not it names `an-dr-ai-use-user-interface`.

## Delivery and approval rules

- Every code delivery begins with 3–5 sentences explaining what changed, why this approach was used, and what was deliberately left out.
- Do not expand scope silently: propose new work as a build iteration, or report it as follow-up work.
- When the user rejects output, redo the delivery from its explanation rather than layering a patch over the rejected approach.
- End a big change with the `an-dr-dev-analyze-changes` HTML report: a Spec or Supervised flow, or any delivery that adds a component, adds an ADR, or changes the architecture. End every other code delivery with a one-line offer to produce it.
- A new point, principle, or piece of information can affect the whole document or change. Revise every affected place so the result stays consistent and correct; never deliver a minimal additive change that leaves the rest contradicting it.
- Push back on workarounds. If no clean solution exists, explain the compromise and let the user decide.

## Kaizen: fix the cause, not just the symptom

When a repository problem blocks work, such as a missing tool, an unset environment, an undocumented prerequisite or a flaky step, getting past it once is not enough. Leave the repository so the next person or agent hits no surprise:

- make the build check for the prerequisite and fail with a message that says how to fix it, or set it up automatically when that is safe;
- document the prerequisite where people look before building (the README or the docs setup page);
- make that change in the same delivery, or report it as follow-up work when it is outside the scope you were given.

Don't install machine-wide software silently. Name what is missing and how to get it, and let the user decide.

## Git rules

- Every flow works on its own branch, named by `an-dr-convention-branch-name`. Do not use git worktrees.
- Before every commit and every push, evaluate all unpushed commits for regrouping: no fixup, WIP, or add-then-remove commits, small same-area changes merged, unrelated concerns apart. `an-dr-git-modify-history` owns the rules; it knows no workflow, so pass it the work's base branch when that is not the default branch.
- Every commit goes through the `an-dr-git-modify-history` skill, which owns the message format. Never write a message from memory. It also rewrites non-conforming messages while the branch is still unpushed.
- Push every commit on a work branch to its remote branch automatically; that push needs no request. Never push the base or default branch automatically: only on explicit request or as part of an integration the user asked for.
- A request merges with the repository's own configured merge method, merge commits included when that is the configuration. Local integration rebases first and never adds a merge commit. Delete the work branch after success, locally and on the remote.
- With no remote, no supported platform CLI, or no authentication, say which is missing and integrate locally instead; ask the user which local `an-dr-dev-integrate` mode to use — keep the commits, regroup them, or squash into one — every time, before the integration touches anything. Approval to integrate is not a choice of mode, and there is no default.
- Integration happens only when the user asks for it, through `an-dr-dev-integrate`, which works on any branch. It lands a branch onto the base its `tmp-agent-wip.json` names, without its `DO-NOT-MERGE:` commits, and no tmp file reaches the base.

## Code conventions

Writing defaults live in `an-dr-dev-implement-code`. The host repository's own instructions override them. Review judges the result on its own terms rather than auditing compliance with the list.

## Temporary artifacts

Outputs that skills generate and that are not repository content, such as code reviews, change reports, and project overviews, are artifacts: take every path from `an-dr-files-find-destination`, giving it only the artifact's kind, whether its latest copy is pinned, and whether it is internal, all declared in the writing skill's metadata. An output the user asks for that no kind fits, such as a custom report, takes no kind. Where artifacts live is owned by `an-dr-convention-artifact-layout` alone; never build or spell out the path by hand. Scratch files and test fixtures are not artifacts: they use the system temp directory.

Deliverables are the exception and are committed as ordinary repository content: ADRs, READMEs, and documentation under `docs/`.

## Skills

Skills use the [Agent Skills](https://agentskills.io/specification) format and live in `skills/<category>/<name>/SKILL.md` next to this file; `skills/README.md` lists each with its one-line use. Read a matching skill before acting and use its public scripts for mechanical operations.

Skill names start with `an-dr-`, and a concept's or convention's name carries `concept-` or `convention-`, so the type shows in a tool's flat skill list. This repository adds two keys under each skill's `metadata`. `an-dr.type` is `action`, `concept`, or `convention`: an action is a procedure you run, while a concept or a convention is passive, a principle or a format you read when its subject is in play and never run. A concept or convention only describes: it contains no steps, no instructions to the agent, and no commands to run, and what to do with it is always the responsibility of an action. This rule has no exceptions. `an-dr.dependencies` lists the skills a skill names. Both are defined by `an-dr-convention-agent-skill`, and a tool that ignores them still reads every skill. In skill commands, `<skill>` is that skill's own folder and `<other-skill>`, such as `<an-dr-git-modify-history>`, is the folder you loaded that skill from. The user never sees raw script output; relay it as `an-dr-ai-use-user-interface` describes.

`an-dr-dev-follow-workflow` sits on top of every other skill. It may name any skill; no other skill names it, a flow, a stage, or its state, or depends on it. Flow-specific behaviour on top of a general skill is written in the workflow skill, which references the general one.

ADRs are immutable once integrated; supersede them instead of editing them, and give the superseded ADR only its "Superseded by" line. Immutability protects a decision others have read, so it begins at integration: an ADR written on the current feature branch is still a draft, and a later decision on that same branch edits it — or collapses two into one — rather than adding an ADR that corrects one nobody has seen. Use ADRs only for lasting architectural decisions, not tactical or tooling choices.

## Commit scopes

Scopes the `an-dr-git-modify-history` skill accepts here, by area rather than by skill directory. Add a scope before using it, and leave it out of a commit that is genuinely cross-cutting.

- policy
- roles
- workflow
- commit
- integrate
- review
- overview
- docs
- install
- tests
- tools

Every file has one correct location in the host repository. Flag ambiguity before creating a file.
