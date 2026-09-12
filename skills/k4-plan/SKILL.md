---
name: k4-plan
description: Compile one exact frozen Goal into a finite contingent partial-order policy for execution. Use after k4-goal to fix dependencies, concurrency, binary routes, checks, and abort handling without performing operations or declaring actual results.
---

# K4 Plan

Compile a static launch decision into the dynamic policy that Run will consume.

## Mandate

Plan alone selects and freezes the finite operation graph by which one exact
Goal may be attempted. It owns operation boundaries, dependency order,
concurrency, pass/fail routing, checks, and abort policy. It does not own the
Goal, execute an operation, or know which result will occur.

## Policy

- Require one exact frozen Goal. If a missing value, scope, acceptance,
  authority, resource, control, effect, or audit boundary prevents planning,
  use the permitted return to Goal rather than silently repairing it.
- Reason, inspect, search, simulate, and compare alternatives as needed for the
  planning responsibility. Such work informs the Plan; it does not itself
  become execution evidence or alter the Goal.
- Keep every operation's tools, permissions, read/write positions, resources,
  and maximum effects within the Goal's execution envelope.
- Give each real operation exactly two result edges, `pass` and `fail`; the two
  edges may share a successor. Use only start, fork, join, and end as virtual
  positions. Keep the graph acyclic and leave genuinely independent work
  unordered.
- A probe may be worthwhile for its information value even when its direct
  success probability is low, provided every resulting route remains within
  Goal.
- Freeze one Plan-level abort policy. Abort is an external or runtime inability
  to continue the graph, not a third operation result.
- Findings and unknowns are annotations, not routes. Coverage links operations
  to possible acceptance evidence; it does not declare any Goal point
  satisfied.
- Do not execute work, record actual results, revise Goal, or declare whether
  the attempt succeeds.

## Procedure

Develop the smallest finite graph that can exercise the frozen Goal. Compare
materially different candidate graphs when doing so changes the selection,
challenge dependencies and failure routes, then freeze one graph with its
selection rationale. Run `scripts/materialize --help`, supply only the semantic
choices requested by that public interface, and bind the exact Goal. The Tool
derives identifiers, bindings, graph projections, and other deterministic
structure.

## Disposition

The stable result is one selected executable Plan: normal entry, abort policy,
finite partial-order graph, Goal coverage, operation envelopes, checks, and
binary routes. It records possibilities only. Run consumes it and actual
evidence selects a route. A semantic change to the process policy requires a
new Plan.

Do not hand-author or patch stable JSON. Ordinary use does not require reading
the CUE contract or Tool source. Correct named public omissions or
contradictions; do not bypass the contract.
