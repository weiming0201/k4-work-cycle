---
name: k4-run
description: Execute only one exact Goal and Plan by appending actual operation, acceptance, control, and stop events to a chained ledger and mechanically projecting current state. Use after k4-plan; do not replan, widen authority, overwrite events, adopt output, or choose the next Goal.
---

# K4 Run

Use this Skill only to execute the frozen Plan and record what actually happens.

## Boundary

- Bind one exact frozen Goal and its exact executable Plan.
- Before each operation, recheck the Plan dependencies, Tool, readable and
  writable positions, permissions, resources, checks, budget, effects, and
  applicable controls.
- Append one event for one actual operation result, acceptance judgment,
  terminal-control judgment, or stop. Operation events carry every invariant
  control check required for that operation.
- Record every potential unresolved issue in that operation's
  `deferred_issues`; do not investigate, repair, prioritize, route, or act on
  it inside the current Run.
- Treat the event ledger as history and the projection as reconstructible
  current state. Never edit an event or treat a projection as history.
- Stop when the Plan cannot govern the next action. Do not silently change the
  route, Tool, dependency, path, Goal, or authorization.

## Form one semantic event

After exactly one governed increment, form exactly one event:

- an operation result identifies the Plan operation, eligibility, actual
  outputs, evidence, trace, result, every applicable invariant-control check,
  and all deferred Findings or unknowns;
- an acceptance result identifies one Goal point and records actual value,
  comparison, evidence, and bounded judgment;
- a terminal-control result records the same for one terminal control;
- a stop records the actual completed, paused, failed, or cancelled state,
  budget and side-effect evidence, and a resume point unless completed.

Do not append `not-run`; it is derived from absence. An operation can pass only
after its dependencies pass and its required evidence and invariant checks are
present. Acceptance can pass only after its mapped operations pass. Append no
event after stop.

## Append and project

Write one temporary semantic event input after the corresponding action or
judgment, then invoke:

```text
scripts/append --input <event-input.json> --log <run.jsonl> --bind goal=<goal.json> --bind plan=<plan.json>
```

Generate a current derived view at an absent path with:

```text
scripts/project --log <run.jsonl> --output <absent-projection.json> --bind goal=<goal.json> --bind plan=<plan.json>
```

The shared Tool creates sequence, time, predecessor and content identities,
locks and appends the ledger, and invokes this Skill's CUE contract. Do not
hand-author, patch, reorder, truncate, or replace stable Run events.

Do not read `assets/protocol.cue`, the shared Tool, or other implementation
source before or during normal use. If append or projection refuses the input,
correct the stated semantic omission or contradiction from its error and this
Skill; do not reverse-engineer the mechanical contract.
