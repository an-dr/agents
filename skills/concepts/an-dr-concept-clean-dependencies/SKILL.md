---
name: an-dr-concept-clean-dependencies
description: Clean-architecture rules for packages, components, and modules — acyclic dependencies, one direction toward stable abstractions, no layer skipping, coherent components, and public contracts only. Use when designing or reviewing structure, adding a dependency between components, splitting or merging them, or judging whether a dependency is acceptable.
license: MIT
metadata:
  author: Andrei Gramakov (an-dr)
  version: "1.0.0"
  an-dr.type: concept
  an-dr.dependencies: PROHIBITED
---

# Concept: clean dependencies

A component is the smallest unit released and reused together: a package, module, library, or skill. The rules below keep a set of components understandable, changeable, and replaceable. They apply to code and to anything else that forms a dependency graph. Folder layout, naming, and declaration syntax are conventions of the host project.

## Dependencies between components

- **No cycles.** The dependency graph is a directed acyclic graph. When a cycle appears, break it: extract the shared part into a new component both depend on, or invert one arrow behind an interface the lower component owns.
- **Depend toward stability.** A component that many others depend on is hard to change, so it must change rarely. Depend on components that change less often than you do, never on a volatile one.
- **Depend toward abstraction.** The more stable a component, the more abstract it should be: interfaces and policy, not details. Volatile detail depends on stable policy, never the reverse.
- **The dependency rule.** Source dependencies point inward, from mechanisms (UI, I/O, frameworks, scripts) toward policy (domain rules, use cases). Inner layers know nothing of outer ones.
- **No layer skipping.** A layer depends on the layer directly beneath it, through that layer's public contract. Reaching past it couples the caller to what the middle layer was meant to hide.
- **Depend on contracts, not internals.** Use a component only through its documented public interface. Another component's files, helpers, and layout are not part of it.
- **Own the interface where it is used.** When a policy needs a detail, the policy defines the interface and the detail implements it, so the arrow runs from detail to policy.

## Inside a component

- **Common closure.** Put together what changes together for the same reason. A change request should touch one component, not many.
- **Common reuse.** Put together what is used together. A consumer should not take a dependency on a component for one part while being exposed to every change in the rest.
- **Reuse and release equivalence.** The unit of reuse is the unit of release: a component has a single owner, a stated purpose, and a boundary a consumer can name.
- **One reason to change.** A component serves one actor. When two actors want different changes to it, split it.
- **Narrow contracts.** Expose the smallest interface a consumer needs. A consumer depends on no method, parameter, or file it does not use.
- **Minimal dependencies.** Each dependency is used by the component's main purpose. A dependency used by one rare branch belongs in a separate component or an optional extension.

## Violations

- Component A depends on B and B on A, directly or through a chain.
- A stable, widely used component depends on a volatile one.
- A high-level component names a concrete detail it should only see as an interface.
- A caller bypasses the layer beneath it to reach a lower one, or into another component's internals.
- A shared component names or special-cases its consumers.
- One component changes for unrelated reasons, or one change request edits many components.
- A consumer carries a dependency for a feature it never uses.

## Reviewing a graph

1. List the components and the arrows between them.
2. Find every cycle and every arrow that skips a layer.
3. For each arrow, check that it points toward the more stable and more abstract component.
4. For each component, check that its contents change together and are used together.
5. Report each violation with the arrow or component involved and the smallest change that removes it.
