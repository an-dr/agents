---
name: an-dr-concept-clean-dependencies
description: Clean-architecture rules for components — acyclic dependencies, one direction toward stable abstractions, no layer skipping, coherent components, and public contracts only. Use when designing or reviewing structure, adding a dependency, splitting or merging components, or judging a dependency.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.1.0"
  an-dr.type: concept
  an-dr.dependencies: PROHIBITED
---

# Concept: clean dependencies

Defers: folder layout, naming, and declaration syntax to the host project's conventions.

## Scope

- A component is the smallest unit released and reused together: package, module, library, or skill.
- The rules apply to code and to anything else forming a dependency graph.

## Dependencies between components

- The dependency graph is acyclic; a cycle is broken by extracting the shared part into a component both depend on, or by inverting one arrow behind an interface the lower component owns.
- A component depends only on components that change less often than it does; a widely depended-on component changes rarely.
- The more stable a component, the more abstract it is: interfaces and policy, not details.
- Source dependencies point inward, from mechanisms (UI, I/O, frameworks, scripts) toward policy (domain rules, use cases); inner layers know nothing of outer ones.
- A layer depends only on the layer directly beneath it, through its public contract.
- A component is used only through its documented public interface; its files, helpers, and layout are not part of it.
- When policy needs a detail, the policy owns the interface and the detail implements it.

## Inside a component

- What changes together for the same reason sits together; a change request touches one component.
- What is used together sits together; a consumer is not exposed to changes in parts it does not use.
- The unit of reuse is the unit of release: one owner, a stated purpose, a boundary a consumer can name.
- A component serves one actor; two actors wanting different changes means a split.
- A contract exposes the smallest interface a consumer needs.
- Every dependency serves the component's main purpose; one used by a rare branch belongs in a separate component or optional extension.

## Violations

- A depends on B and B on A, directly or through a chain.
- A stable, widely used component depends on a volatile one.
- A high-level component names a concrete detail it should see only as an interface.
- A caller bypasses the layer beneath it, or reaches into another component's internals.
- A shared component names or special-cases its consumers.
- One component changes for unrelated reasons, or one change request edits many components.
- A consumer carries a dependency for a feature it never uses.
