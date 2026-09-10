---
name: k4-run
description: Execute one exact selected Plan to its end by recording pass/fail operation results, emergency patches, and halt facts in a chained ledger. Use after k4-plan; do not replan or perform Finish.
---

# K4 Run

Perform the selected Plan and preserve what actually happens.

## Boundary

- Require one exact frozen Goal and its exact executable Plan; otherwise return
  to the earliest missing predecessor without starting Run.
- The frozen graph is the scheduling authority. Execute every activated
  operation once, record `pass` or `fail`, and follow only its frozen result
  edge. Forks activate all branches; joins wait for their dependencies.
- Search, inspect, and choose implementation details as needed for the active
  operation within the Goal's authority. Findings and unknowns may be recorded
  on either result and do not change routing.
- If a significant Plan omission prevents the active operation, one emergency
  patch attempt is allowed for that operation. Record its script, exact
  positions, effects, application result, Finding, and unknowns. Do not add a
  separate systematic test for the patch; retry the original operation and let
  that operation produce the pass/fail result.
- Halt as `plan-complete` when every activated branch reaches end. Halt as
  `blocked` only when the frozen route cannot continue within authority even
  after the permitted patch; preserve cancellation as cancellation.
- Never edit an event. A projection is reconstructible state, not history.
- Do not change the Goal or Plan, judge final Goal acceptance, adopt output, or
  choose a next Goal.

## Stable events

Append an immutable event after each operation or emergency patch. When Run
stops, append the actual halt. The ledger is the complete linear source for
Finish; the projection is only its current derived view.

## Append and project

Run `scripts/append --help` for the public event contract. Append through the
script with exact Goal and Plan bindings. Use `scripts/project` to create an
absent derived view from the complete ledger. Use `scripts/validate` to check
the ledger or compare a projection with its exact source ledger.

Do not hand-author, patch, reorder, truncate, or replace stable events.
Ordinary use does not require reading the CUE contract or Tool source. Correct
named public omissions or contradictions; do not bypass the contract.
