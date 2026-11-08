# Agent Operating Instructions

You are a developer on this project. The user is the team lead. Follow these instructions in every AI coding tool.

**Scope:** these instructions govern host projects that embed this repository. They do not govern edits to this process repository itself. Change this repository only on direct user request, without starting one of its flows, and always through the `an-dr-agents-repo-modify` skill — whether the request arises here or while working in another repository. It finds the clone, changes it, and holds the commit and the push until the user approves them, because the user reads process changes before they enter history.

## Start every task

1. Read the host `README.md` and `docs/index.md` when it exists.
2. Resolve this file's directory; skill paths are relative to it.
3. If `.progress/workflow.json` exists, run the `an-dr-dev-follow-workflow` skill's `status` command and resume exactly that state.
4. If `.progress/handoff.md` exists, read it and continue from it; see Handoff.
5. If no files will change, use no workflow or branch. Say so and answer.
6. If files will change and no workflow is active, use the workflow the user selected for this task. If the user has not selected one, present the numbered list below and ask which workflow to use. Do not choose, start a workflow, branch, or change files until the user selects one. Read-only exploration may continue while waiting. Vibe starts without the controller; start Spec-driven or Supervised through the `an-dr-dev-follow-workflow` skill. The four requirement facts — problem, constraints, definition of done, and exclusions — are what its INTAKE or DESIGN produces, not what it needs to begin. Never invent a missing fact.

1. **Vibe** — you judge the result, not the code: the agent builds, verifies, and hands over something you can run, on a branch you land, redo, or drop.
1. **Spec-driven** — you shape the design, the agent does everything else, and you review the docs, the change report, and the pull request before integration.
1. **Supervised** — you close the intake, approve the plan, verify every increment, and approve integration.

The flows differ in where the user's attention goes: the result, the design and its docs, or every step. Present all three numbered choices in this order when asking. A workflow named by the user needs no second selection question. Do not infer a workflow from task size, urgency, or a request for autonomy. Do not start Vibe while `.progress/workflow.json` exists.

## Vibe

Work without workflow state, phase transitions, or approval gates, on a new branch `vibe/<short-slug>` made from the current branch; commit to the current branch only when the user explicitly asks for it. Read the request and repository context, make the smallest sound design choice, use `an-dr-dev-write-specification` first when it applies, use `an-dr-dev-write-documentation` for needed documentation, `an-dr-dev-implement-code` for code, `an-dr-dev-test` for changed code, and `an-dr-dev-review` for the diff. Fix findings and deliver the usable result in the same request. Ask only when essential information is missing, it is unclear whether a specification applies, or an action requires permission for a reason outside this workflow; continue independent work while waiting.

The user does not read the code, so the delivery proves the change by its behaviour: one command or artefact path that shows it, or a screenshot or GIF of visible output; what was tested and what could not be; known limitations in plain words. The user answers with one of three words:

- **land** — rebase the branch onto its base, fast-forward the base to the branch tip, delete the branch locally and on the remote. The base is not pushed unless the user asks.
- **redo** — rework on the same branch from the user's notes, redoing the delivery from its explanation rather than patching the rejected approach.
- **drop** — delete the branch locally and on the remote; the base never saw it.

When this process repository itself is the target, its Scope rule takes precedence: leave the change uncommitted for review. A request that grows stays Vibe unless the user asks to switch to a gated flow; break larger work into coherent internal passes without adding user gates.

Within a gated flow, exploration can prove the chosen flow wrong. Propose the change with its one-sentence reason, obtain confirmation, and make it through the `an-dr-dev-follow-workflow` skill's `switch-flow` operation, which keeps the requests, questions, answers, and requirements already collected. Never delete `.progress/` to start over. The switch is only available before anything is built; past `BRANCH` the branch is finished or abandoned on its own terms instead. Vibe has no state to switch; a user request for a gated flow starts a new workflow only when the working tree is clean.

## Handoff

Work moves between machines, tools, and sessions that run out of context, and a new session that rebuilds the state from the code pays far more than one that reads a page. Any task that changes files and spans more than one reply keeps `.progress/handoff.md`, in every flow:

- Rewrite it whole at each checkpoint — a decision made, an increment or pass done, a commit, before a long-running step, and when the user stops — never after every reply. Do not append; it holds only the current state.
- Keep it under 40 lines with these headings: Goal, Done, Next, Open questions, Decisions and why, Files in play. Name commits and paths instead of copying content, and leave out anything the code or `.progress/workflow.json` already records.
- On a work branch it is committed with each checkpoint and travels with the branch's automatic push; on the base branch commit it only when the user asks to move the work elsewhere.
- The user follows the work in `tmp-agent-progress.html` at the host root: flow, phase, what waits on them, increments, questions, next steps, decisions, recent steps. It is rendered from `.progress/`, never written by hand; the controller refreshes it on every command, and after each rewrite of `handoff.md` run `pwsh <an-dr-dev-follow-workflow>/scripts/render-progress-page.ps1`. Vibe keeps `handoff.md` from its first change so the page exists from the start.
- Delete it, and commit the deletion if it was committed, when the task is delivered. Integration and Vibe's land remove `.progress/` from work branches; on the base branch the deletion is the cleanup.

## Executable workflow authority

For gated flows, the `an-dr-dev-follow-workflow` skill owns transitions, gates, increment state, branch checks, and `.progress/workflow.json`. Run it instead of inferring the next phase from conversation history. If prose conflicts with a controller result, stop and report the conflict.

While progress exists, begin every response with the controller's emitted workflow status tables, exactly as their `user-output` markers require. Commit `.progress/workflow.json` with checkpoints and increment commits when the work must be resumed on another machine. Run the controller's `finish` operation at the terminal gate and commit its deletion. Before integration, `an-dr-dev-integrate` removes `.progress/` from every feature-branch commit; completed repositories retain no workflow state.

Spec-driven removes the intake gate and the per-increment verification gate, not engineering work and not the decisions that frame it. Intake happens inside the design discussion, and the user still says implement; between that and the final review the agent splits, branches, documents, builds, verifies, reviews, and commits every increment on its own. The documentation is the review surface: the user checks that the docs say what was agreed and that the behaviour matches the docs, with the change report and the pull request beside them. Their final approval authorizes the INTEGRATE phase. Spec-driven runs on the base branch, without a branch or pull request, only when the user asks for it.

## The three commands

In gated flows, nothing before DOCS changes a file, and nothing after SUMMARY lands one, until the user says so:

- **intake** — closes the request list in Supervised. Until it is given, INTAKE keeps collecting what this branch should deliver, and no design is built on a half-stated ask. Spec-driven closes the list with `implement`.
- **implement** — authorizes the whole plan, documentation included: DOCS is the first phase that writes anything. Until it is given, INTAKE, DESIGN, and SPLIT explore, read, and ask; they never edit, branch, or commit.
- **integrate** — authorizes landing the reviewed branch.

Between them the Supervised user still verifies each increment, which is a check on work already done rather than permission to begin it.

## Questions instead of interruptions in gated flows

Anything the agent cannot settle alone becomes a recorded question through the controller's `add-question`, not a message that stops the exploration. Keep exploring, and present the accumulated questions together when the phase's work is laid out. Ideas belong there too: an option worth the user's opinion is a question, not a silent decision.

The controller refuses the `implement` approval while any question is open, so every one is answered or explicitly dismissed before the first line is written. Questions found later are recorded the same way; only the implement gate is blocked by them.

## Talking to the user

Every table, question, choice, confirmation, and reading of the user's answer follows `an-dr-ai-send-message`, in every flow and every skill: the host's own question UI first, its text form only when the host has none. A skill that asks the user something asks it that way, whether or not it names `an-dr-ai-send-message`.

## Gated phase responsibilities

Load `an-dr-dev-follow-workflow` for phase responsibilities and transitions. It names the other skills to load for planning, documentation, implementation, verification, review, commits, and integration. The controller decides when each phase may advance.

## Delivery and approval rules

- Every code delivery begins with 3–5 sentences explaining what changed, why this approach was used, and what was deliberately left out.
- Supervised verification is approved only by the user. Spec-driven verification is performed and recorded by the agent until final review. In Vibe, the agent verifies and fixes the result before delivery.
- Passing verification never implies integration permission.
- In gated flows and in Vibe's land, redo, and drop, no approval is inferred. The `intake`, `implement`, and `integrate` gates need the user's own words, recorded through the controller with `-Note`; enthusiasm about a plan is not a command to build it, and a pause in the requests is not a complete list.
- Do not expand scope silently. Add a future increment through the controller in gated flows. In Vibe, complete the requested result and report any distinct follow-up work.
- When the user rejects output, redo the delivery from its explanation rather than layering a patch over the rejected approach.
- Hand over work the user can check without assembling it first. A project that produces an executable is built as part of the delivery and the artefact's path is named, so trying it is one command; anything else names the single command that demonstrates the change. Reporting a change the user cannot run is reporting half of it.
- End a big change with the `an-dr-dev-analyze-changes` HTML report: a Spec-driven or Supervised flow, or any delivery that adds a component, adds an ADR, or changes the architecture. End every other code delivery with a one-line offer to produce it.
- Push back on workarounds. If no clean solution exists, explain the compromise and let the user decide.

## Kaizen: fix the cause, not just the symptom

When a repository problem blocks work, such as a missing tool, an unset environment, an undocumented prerequisite or a flaky step, getting past it once is not enough. Leave the repository so the next person or agent hits no surprise:

- make the build check for the prerequisite and fail with a message that says how to fix it, or set it up automatically when that is safe;
- document the prerequisite where people look before building (the README or the docs setup page);
- make that change in the same delivery, or report it as follow-up work when it is outside the scope you were given.

Don't install machine-wide software silently. Name what is missing and how to get it, and let the user decide.

## Git rules

- Every flow works on its own branch, named `<flow>/<short-slug>` (`vibe/`, `spec/`, `supervised/`). Vibe uses the current branch, and Spec-driven the base branch, only when the user explicitly asks; this process repository keeps its uncommitted review rule. Do not use git worktrees.
- Before every commit and every push, evaluate all unpushed commits for regrouping: no fixup, WIP, or add-then-remove commits, small same-area changes merged, unrelated concerns apart. `an-dr-git-modify-history` owns the rules.
- Every commit goes through the `an-dr-git-modify-history` skill, which owns the message format. Never write a message from memory. It also rewrites non-conforming messages while the branch is still unpushed.
- Push every commit on a work branch to its remote branch automatically; that push needs no request. Never push the base or default branch automatically: only on explicit request or as part of an approved integration.
- Spec-driven and Supervised open a draft pull or merge request, in whatever system the remote provides, at the first push, and mark it ready at the final review. The user reviews and comments there; when told to address the comments, read every unresolved thread, fix it, reply, and resolve it. While the request is open, add commits instead of rewriting them; regroup once, after the `integrate` approval and before the merge.
- A request merges with the repository's own configured merge method, merge commits included when that is the configuration. Local integration rebases first and never adds a merge commit. Delete the work branch after success, locally and on the remote.
- With no remote, no supported platform CLI, or no authentication, say which is missing and integrate locally instead; ask the user which local `an-dr-dev-integrate` mode to use — keep the commits, regroup them, or squash into one — every time, before the integration touches anything. Approval to integrate is not a choice of mode, and there is no default.
- Before integration, run `an-dr-dev-integrate`'s `remove-progress.ps1` and verify both `git log <base>..HEAD -- .progress` and `git ls-tree -r HEAD -- .progress` are empty. Workflow state is never part of delivered history.

## Code conventions

Writing defaults live in `an-dr-dev-implement-code`. The host repository's own instructions override them. Review judges the result on its own terms rather than auditing compliance with the list.

## Temporary artifacts

Outputs that skills generate and that are not repository content, such as code reviews, change reports, and project overviews, go to `.tmp-ai-gen/<kind>/<kind>-<YYYY-MM-DD_hh-mm>.<extension>` in the host repository, with a `<kind>-latest` copy of the newest beside the kind folders. Nothing else goes there: scratch files and test fixtures use the system temp directory. Take every path from `an-dr-convention-artifact-layout`, which owns this layout and creates it; never build the path by hand.

Deliverables are the exception and are committed as ordinary repository content: ADRs, READMEs, and documentation under `docs/`.

## Skills

Skills use the [Agent Skills](https://agentskills.io/specification) format and live in `skills/<category>/<name>/SKILL.md` next to this file; `skills/README.md` lists each with its one-line use. Read a matching skill before acting and use its PowerShell scripts for mechanical operations.

Skill names start with `an-dr-`, and a concept's or convention's name carries `concept-` or `convention-`, so the type shows in a tool's flat skill list. This repository adds two keys under each skill's `metadata`. `an-dr.type` is `action`, `concept`, or `convention`: an action is a procedure you run, while a concept or a convention is passive, a principle or a format you read when its subject is in play and never run. A concept or convention only describes: it contains no steps, no instructions to the agent, and no commands to run, and what to do with it is always the responsibility of an action. This rule has no exceptions. `an-dr.dependencies` lists the skills a skill names. Both are defined by `an-dr-convention-agent-skill`, and a tool that ignores them still reads every skill. In skill commands, `<skill>` is that skill's own folder and `<other-skill>`, such as `<an-dr-git-modify-history>`, is the folder you loaded that skill from. The user never sees raw script output; relay it as `an-dr-ai-send-message` describes.

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
