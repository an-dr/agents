# Intake and planning

## Collect the intake

- `INTAKE` collects what the branch should deliver over as many messages as it takes; record each request as it arrives; map the repository between them, turning findings into questions.
- Requests exist only during `INTAKE`; afterwards new scope is an increment.
- Leaving `INTAKE` needs at least one request, all four requirement fields set, and in Supervised the `intake` approval. Spec-driven moves on as soon as the list and the four facts stand, and keeps adding requests through the design discussion until `implement`.
- The four facts distil the whole request list, including the exclusions it implies; never invent one, ask it as a question.
- The list stays in state so `SUMMARY` checks the branch against it.

```powershell
pwsh <script> add-request -Text '<something the user wants from this branch>'
pwsh <script> remove-request -Number 3
pwsh <script> set-requirement -Field goal -Value '<the problem>'
```

## Plan the gated work

- INTAKE, DESIGN, and SPLIT are read-only: read host `README.md`, `docs/index.md`, architecture docs, and ADRs; identify invariants and patterns; map every touch-point including docs, schemas, and tests; record unresolved choices with `add-question`.
- Start of DESIGN → decide whether `an-dr-dev-write-specification` applies; if so, draft the specification first and choose options within it.
- DESIGN: present 2–4 real options with tradeoffs and let the user choose, in both flows; Spec-driven ends DESIGN with a short design summary (problem, approach, interfaces, exclusions, definition of done) that becomes the spec its DOCS phase writes. Deeper decision → `an-dr-dev-design`; lasting architectural decision → `an-dr-convention-adr`.
- New project without CI → plan an `an-dr-dev-implement-pipeline` increment unless the user excluded it.
- Before leaving SPLIT: every request covered, every question answered or dismissed, each increment names its documentation work; increments about 300 changed lines or less.
- Present the numbered plan with estimated lines and answered questions before the `implement` approval.
