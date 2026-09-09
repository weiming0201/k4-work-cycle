---
name: k4-align
description: Iteratively reconcile one bounded situation into a full sourced account of retained, changed, added, retired, open, conflicting, and unknown items before selecting a new Goal. Use at cold start or after new evidence; do not use it to define acceptance or perform corrective work.
---

# K4 Align

Use this Skill only to create the next full account of one bounded situation.

## Boundary

- With no predecessor, create `Align[0]` from one bounded subject and declared
  evidence set.
- With a predecessor, bind its exact bytes, supply the evidence delta, and emit
  a new full account with every prior item retained, changed, or retired and
  every new item marked added.
- Preserve facts, source statements, inferences, preferences, and unknowns as
  distinguishable statements. A route of `goal-candidate` only exposes a
  possible input; it does not create a Goal.
- Do not mutate the observed object, write acceptance points, choose a Plan, or
  reinterpret a failed Run as success.

## Form the semantic input

State the bounded subject, included and excluded observation boundary, evidence
cutoff, and complete set of source references. Describe this iteration's
evidence delta. For every current item provide:

- whether it is retained, changed, or added;
- its predecessor when retained or changed;
- why that continuity relation holds;
- whether the current statement is aligned, a gap, a conflict, or unknown;
- the minimum supported statement and its evidence references;
- whether it exposes a Goal candidate, stays retained, has no route, or points
  to an external destination.

List every retired predecessor with its reason and delta evidence. At
bootstrap every item is added and there are no predecessors or retired items.
On iteration, account for every prior item exactly once. Changed, added, and
retired items cite evidence from this iteration.

## Materialize

Write only a temporary semantic JSON input, then invoke:

```text
scripts/materialize --input <semantic-input.json> --output <absent-align.json> (--null-bind previous_align | --bind previous_align=<prior-align.json>)
```

The script calls the shared deterministic Tool with this Skill's CUE contract.
Do not hand-author or patch the stable document. Mechanical success proves the
declared full projection and delta relation only; it does not prove that the
declared evidence exhausts reality.

Do not read `assets/protocol.cue`, the shared Tool, or other implementation
source before or during normal use. If materialization refuses the input,
correct the stated semantic omission or contradiction from its error and this
Skill; do not reverse-engineer the mechanical contract.
