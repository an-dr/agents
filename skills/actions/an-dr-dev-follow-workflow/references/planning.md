# Request, design, and plan

## Request

- `INTAKE` collects what the branch should deliver over as many messages as it takes; record each request as it arrives; map the repository between them, turning findings into questions.
- Requests exist only during `INTAKE`; afterwards new scope is a build iteration.
- Leaving `INTAKE` needs at least one request and all four requirement fields set; Supervised also needs the scope approved.
- The four facts distil the whole request list, including the exclusions it implies; never invent one, ask it as a question.
- The list stays in state so `SUMMARY` checks the branch against it.

```sh
python <script> add-request --text '<something the user wants from this branch>'
python <script> remove-request --number 3
python <script> set-requirement --field goal --value '<the problem>'
```

## Design

- Read host `README.md`, `docs/index.md`, architecture docs, and ADRs; identify invariants and patterns; map every touch-point including docs, schemas, and tests; record unresolved choices with `add-question`.
- New work → `an-dr-dev-write-specification` first, drafted in `tmp-specification.md` at the host root while the stages are read-only; its unclear cases become questions. Deeper decision → `an-dr-dev-design`; lasting architectural decision → `an-dr-convention-adr`.
- Spec: the agent proposes the design. Supervised: ask the user to explain the design, then polish it with them.
- Present the design with its answered questions before asking for the design approval.

## Plan

- Cut the design into build iterations, each a part that can be documented, verified, and committed on its own, each naming its documentation work.
- New project without CI → plan an `an-dr-dev-implement-pipeline` iteration unless the user excluded it.
- Every request covered before leaving `SPLIT`.
- Spec: the plan is the agent's. Supervised: iterations of about 300 changed lines or less; present the numbered plan before asking for the plan approval.
