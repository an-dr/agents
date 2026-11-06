---
name: an-dr-dev-write-specification
description: Write the high-level specification of a new project or a completely new feature — its use cases and its architecture — before any lower-level design or code. Use when starting a new project or establishing a capability the system does not have yet, or when the user asks to specify an existing feature; ask first when it is unclear whether the work is new.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: action
  an-dr.dependencies: an-dr-ai-send-message an-dr-concept-clean-dependencies an-dr-convention-adr an-dr-convention-use-case an-dr-dev-write-documentation
---

# Specification

Says what a new project or feature must do and what shape it takes: its use cases and its architecture, and nothing below them. `an-dr-convention-use-case` owns the use-case format, `an-dr-convention-adr` the decision records, and `an-dr-dev-write-documentation` the writing of the final documents.

## Decide whether it applies

| The work is                                                             | Do                                                 |
| ----------------------------------------------------------------------- | -------------------------------------------------- |
| a new project                                                           | apply this skill                                   |
| a capability the system does not have yet, with its own actors or goals | apply this skill                                   |
| a change to an existing feature, a fix, or a refactoring                | skip it, unless the user asked for a specification |
| anything you cannot place in one of these rows                          | ask the user                                       |

Ask as an `an-dr-ai-send-message` question, naming the work and why it is unclear. In a gated flow, record it as a controller question first. Never guess in either direction.

## Establish the context

Read the request, the host's `README.md`, `docs/index.md`, and any existing use cases, architecture documents, and ADRs. For a new feature, note which existing use cases it could break and which boundaries it crosses. Ask for what is missing: never invent an actor, a goal, or a constraint.

## Define the use cases

1. Name the actors by what they do.
2. Group the goals into areas by the user's activity, and write one use case per goal following `an-dr-convention-use-case`.
3. Cover what the first delivery needs. List goals deliberately left out as exclusions rather than writing them as use cases.

## Define the architecture

Derive the architecture from the use cases, so that each use case can be traced through it and each part serves at least one use case. State:

- **Context:** the system's boundary, its actors, and the external systems it relies on.
- **Components:** each major part and its one responsibility, with dependencies that follow `an-dr-concept-clean-dependencies`.
- **Boundaries and guarantees:** what crosses between parts in concept, and what the system promises, such as durability, offline use, or security limits.
- **Decisions:** the choices that would be expensive to reverse, with the alternatives considered. Each lasting one becomes an ADR following `an-dr-convention-adr`.

Draw a diagram when the structure is not obvious from one short list. Leave out function signatures, schemas, file formats, algorithms, and the task plan: lower-level design and implementation settle those within this architecture.

## Check

- Every use case passes the convention's review, and maps to the components that deliver it.
- Every component and every decision serves a use case or a stated constraint.
- Each assumption is marked as an assumption, and every open choice is a question to the user.

## Output

| Part              | Location                                                                                              |
| ----------------- | ----------------------------------------------------------------------------------------------------- |
| Use cases         | `docs/use-cases/`, as `an-dr-convention-use-case` lays out                                            |
| Architecture      | `docs/architecture.md`, or the host's existing architecture document, extended rather than duplicated |
| Lasting decisions | ADRs                                                                                                  |

- **Gated flow:** keep the draft in `.progress/specification.md` during the read-only phases and show it to the user before the `implement` gate. Write the final documents with `an-dr-dev-write-documentation` in the first DOCS phase, then delete the draft.
- **Direct:** write the final documents with `an-dr-dev-write-documentation` before the code, and name them in the delivery.

## Rules

- **High level only.** A statement that would change in an ordinary refactoring does not belong in the specification.
- **Use cases first.** Architecture that serves no stated goal is removed, or the missing goal is raised with the user.
- **One home per fact.** Link to an existing use case or architecture section instead of restating it.
