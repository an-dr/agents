# Review checklist

## Ergonomics

Code pleasant for a human to use and read. Findings, even when the code is correct:

- a public interface that is not obvious to call correctly or is easy to call wrongly;
- a name that does not say what it does;
- control flow that cannot be followed top to bottom without holding hidden state in mind;
- a change a reader unfamiliar with it cannot understand from the code and its inline docs alone.

## Cost to the next reader

A finding only when it costs the next reader or change:

- a unit doing several jobs;
- a stale or obvious comment;
- a public interface without useful documentation;
- duplicated facts, swallowed errors, dead code, options nothing calls.

## Architecture and reviewability

Judged against `an-dr-concept-clean-dependencies` and the Architecture, Names and structure, and Reviewable changes sections of `an-dr-convention-code`. Findings:

- dependencies pointing outward;
- a lifecycle held as scattered flags;
- a unit that gained a second responsibility;
- coupling to another component's private internals;
- a boundary format built outside the shared codec;
- optional members every implementation provides;
- names that describe a previous design, or one name for two concepts;
- structure or names an experienced developer in that ecosystem would not expect;
- stale references to removed code;
- a missing ADR for a new public contract or ADR exception;
- formatting-only or mechanical changes mixed into behaviour changes;
- a SUMMARY branch whose commits cannot each be reviewed and bisected as one concern → `high`.

## Diagrams

A finding may carry one Mermaid diagram through `-Diagram '<source>'` or `-DiagramPath <file>`.

- Attach one when the problem is structural and a picture explains it faster than prose: a dependency pointing the wrong way, a request or handoff flow going wrong, a lifecycle with a missing transition, unclear ownership.
- Not for a line-level defect.
- Draw only what the code shows; diagram type and format follow `an-dr-convention-html-report`.
