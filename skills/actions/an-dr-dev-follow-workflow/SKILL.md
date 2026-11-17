---
name: an-dr-dev-follow-workflow
description: Run, resume, and enforce Vibe, Spec, or Supervised along the common path and each flow's approvals. Use when the user selects a flow, tmp-agent-wip.json exists, the handoff needs rewriting, work moves to another machine, or build iterations change.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "4.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-use-user-interface an-dr-ai-use-wip-data an-dr-convention-adr an-dr-convention-branch-name an-dr-dev-analyze-changes an-dr-dev-debug an-dr-dev-design an-dr-dev-implement-code an-dr-dev-implement-pipeline an-dr-dev-integrate an-dr-dev-review an-dr-dev-test an-dr-dev-write-documentation an-dr-dev-write-readme an-dr-dev-write-specification an-dr-git-modify-history
---

# Workflow controller

Owns: the `workflow` section of `tmp-agent-wip.json`, every flow's state, kept through `an-dr-ai-use-wip-data`, and the transitions and approvals of every flow, through `scripts/workflow.py`.

## Start or resume

1. From the host root, locate this skill relative to the active `AGENTS.md`; `<script>` below is `<skill>/scripts/workflow.py`. Every command also takes `--wip-data-skill <an-dr-ai-use-wip-data>`, left out of the examples below.
2. While `tmp-agent-wip.json` holds a `workflow` section, run `status` first in every response and present its Markdown table verbatim, as its `user-output: verbatim` markers require. That table, not the JSON file or the conversation, decides the stage, the approvals, and open questions.
3. Command fails → quote the command and its error and stop; never reconstruct state from the file.
4. No active state → start as soon as the flow is chosen, on the branch the work returns to; it is recorded as the base. Only `--flow` is required; pass whichever of the four facts the request makes plain.

```sh
python <script> status
python <script> start --flow Vibe|Spec|Supervised [--goal '<problem>']
```

The controller's stages map onto the common path:

| Common path      | Spec and Supervised stages                                       | Vibe stages                 |
| ---------------- | ---------------------------------------------------------------- | --------------------------- |
| Request          | `INTAKE`                                                         | —                           |
| Design           | `DESIGN`                                                         | —                           |
| Plan             | `SPLIT`                                                          | —                           |
| Build iterations | `BRANCH`, then per iteration `DOCS`, `BUILD`, `VERIFY`, `COMMIT` | `BUILD`, `VERIFY`, `COMMIT` |
| Approval         | `SUMMARY`                                                        | `HANDOVER`, before `finish` |
| Handover         | `HANDOVER`                                                       | `HANDOVER`                  |

- Vibe keeps no requests or build iterations; `return-to-build` is its redo and drops the result approval.
- State from a retired flow resumes as its successor (`Detailed` → `Supervised`, `DetailedAuto` and `SpecDriven` → `Spec`); a `Quick` state is refused with instructions.

## Work by stage

- `INTAKE`, `DESIGN`, and `SPLIT` are read-only: no edit, branch, or commit. In them, read [references/planning.md](references/planning.md).
- From `BRANCH` on, read [references/phases.md](references/phases.md) for the skills and checks of the current stage, and at `SUMMARY` [references/summary.md](references/summary.md).

## Approvals

| Gate              | Stage      | Flows            | The user approves               |
| ----------------- | ---------- | ---------------- | ------------------------------- |
| `scope-approved`  | `INTAKE`   | Supervised       | the request list as complete    |
| `design-approved` | `DESIGN`   | Spec, Supervised | the design                      |
| `plan-approved`   | `SPLIT`    | Supervised       | the plan of build iterations    |
| `step-approved`   | `VERIFY`   | Supervised       | one build iteration             |
| `result-approved` | `SUMMARY`  | Spec, Supervised | the result                      |
| `result-approved` | `HANDOVER` | Vibe             | the built result, by running it |

```sh
python <script> approve --gate design-approved --note '<the user's words>'
```

- Show what is being approved, then read the user's reply: one that plainly approves passes the gate, one that asks for changes does not; when unsure, ask one `an-dr-ai-use-user-interface` confirmation.
- `--note` holds the user's words that approved it. The controller records approvals and never supplies them.
- A request recorded after the scope approval drops it. `design-approved` is refused while a question is open.

## Operate the workflow

```sh
python <script> add-question --text '<what the user must decide>'
python <script> answer-question --number 2 --answer '<the user's answer>'
python <script> dismiss-question --number 3 --answer '<why it stopped mattering>'
python <script> advance
python <script> return-to-build
python <script> switch-flow --flow Supervised
python <script> add-increment --at 2 --scope '<scope>' --description '<result>'
python <script> move-increment --number 4 --to 2
python <script> defer-increment --to 6
python <script> remove-increment --number 7
python <script> set-handoff --handoff-field next --items '<entry> | <entry>'
python <script> finish
```

- An increment is a build iteration.
- Every state-changing command renders `tmp-agent-progress.html` at the host root, grouped by the common path; it is excluded from git and removed at `finish` and when no state exists.
- `set-handoff` replaces one handoff field whole: `goal` takes one text; `done`, `next`, `openQuestions`, `decisions`, and `files` take entries separated by ` | ` or newlines.
- `advance` rejects missing approvals or iterations, wrong branches, uncommitted iterations, and illegal transitions.
- `return-to-build` resumes `BUILD` for the same iteration and drops its step approval.
- Before changing iterations, read [references/increments.md](references/increments.md); before `switch-flow`, read [references/switch-flow.md](references/switch-flow.md).

## Share and finish

- Before committing progress state, moving work to another machine, or running `finish`, read [references/finish.md](references/finish.md).
