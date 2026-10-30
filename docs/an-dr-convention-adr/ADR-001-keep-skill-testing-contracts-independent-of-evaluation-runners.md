# ADR-001: Keep skill testing contracts independent of evaluation runners

## Problem

Behavioral cases and their schema were owned by the test-authoring action, while packaging rules were repeated in script and repository conventions. Cases did not declare an execution environment. This coupled the preserved behavior to an authoring procedure and left isolation assumptions outside the test data.

## Decision

Make the agent skill testing convention the authority for the versioned evaluation contract, environment requirements, ZIP fixtures, assertions, and deterministic test layout. Keep cases in each skill's `evals/evals.json` with intent in `evals/EVAL.md`; keep script tests and their runner in `scripts/tests/`. Authoring and execution actions consume the convention's public validator. The repository entry point discovers conventional local runners; the owning skill suites supply repository validators and evaluation-data checks. The contract remains independent of any model provider or evaluation CLI.

## Rationale

A stable contract lets different host adapters execute the same inputs and preserve evidence without inheriting the author's conversation or private grading rubric. Environment preflight and resolved run manifests distinguish blocked infrastructure from failed behavior. ZIP snapshots preserve addition, deletion, and unchanged-file evidence without carrying live Git configuration. Free CI checks remain separate from explicitly requested paid evaluations.

## Rejected alternatives

Adopting an external runner's schema would make the repository's preserved behavior depend on that tool's lifecycle. Keeping the contract in the authoring action would retain the ownership ambiguity. Automatically evaluating every PR would violate the user's selected execution policy and introduce unbounded paid work.
