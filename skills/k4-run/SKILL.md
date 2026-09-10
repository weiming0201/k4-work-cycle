---
name: k4-run
description: Execute one exact Goal and Plan by appending actual operation and halt facts to a chained ledger and mechanically projecting current execution state. Use after k4-plan; do not judge terminal acceptance, replan, widen authority, adopt output, or choose the next Goal.
---

# K4 Run

Use this Skill only to perform the frozen Plan and record what actually happens.

## Boundary

- Require one exact frozen Goal and its exact executable Plan; otherwise return
  to the earliest missing predecessor without starting Run.
- Before each operation recheck dependencies, tool, paths, permissions,
  resources, checks, budget, effects, and invariant controls.
- Attempt only one eligible Plan operation per increment and append its actual
  result, outputs, evidence, trace, invariant observations, and deferred issues.
- Append one halt event when no next operation will be attempted. Preserve the
  actual halt position, trigger, budget/effect evidence, and resume evidence.
- Never edit an event. A projection is reconstructible state, not history.
- Do not judge Goal acceptance or terminal controls, declare overall completion,
  repair, replan, widen scope, adopt, or choose a next Goal.

## Form one semantic event

After one governed operation, describe its Plan identity, eligibility, actual
outputs, evidence, trace, result, every mapped invariant-control observation,
and all deferred issues. An out-of-scope issue is recorded but not investigated
or acted on. A drift affecting the operation prevents a passing result.

When execution stops, append a halt with actual position, trigger, observed
budget and effects, evidence, and available resume reference. Halt is an
execution fact; Finish determines the attempt's terminal judgment.

## Append and project

Run `scripts/append --help` before authoring each temporary event. Append it
through the script with exact Goal and Plan bindings. Use `scripts/project` to
create an absent derived view from the complete ledger.

Do not hand-author, patch, reorder, truncate, or replace stable events.
Ordinary use does not require reading the CUE contract or Tool source. Correct
named public omissions or contradictions; do not bypass the contract.
