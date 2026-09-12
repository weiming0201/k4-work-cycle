---
name: k4-run
description: Execute one exact selected Plan to its terminal topology while preserving actual operation, patch, abort, and halt facts in a chained ledger. Use after k4-plan; local results choose routes but do not decide whole-Goal acceptance or perform Finish.
---

# K4 Run

Turn the Plan's licensed possibilities into an immutable history of what
actually happened.

## Mandate

Run alone performs the operations activated by one exact Plan and records their
actual consequences. It may test enough to choose the operation's frozen
`pass` or `fail` edge. It does not decide whether the Goal, product, or whole
attempt passed; that responsibility belongs to Finish.

## Policy

- Require one exact frozen Goal and its executable Plan. Without both, return a
  named missing-predecessor refusal and do not start a ledger.
- Use the frozen graph as scheduling authority. Execute each activated real
  operation once, record its local `pass` or `fail`, and follow only the
  corresponding edge. Forks activate branches and joins await dependencies.
- Reason, inspect, search, test, compare, and choose implementation details as
  needed for the active operation inside its envelope. Developer tests support
  routing; they are not whole-attempt acceptance.
- Record findings, unknowns, and recommendations without amending Observe,
  Goal, or Plan. Thinking about another responsibility is allowed; exercising
  that responsibility is not.
- If a significant Plan omission matches that operation's frozen patch seam,
  allow its one emergency patch attempt. No seam means no patch authority.
  Record
  its script, boundaries, effects, result, findings, and unknowns. Do not add a
  systematic validation objective for the patch; retry the original operation
  and let that operation select its route.
- Confirm abort only from an explicit external or runtime fact while the normal
  route remains open, then follow the Plan's frozen abort policy. Abort is not
  an operation result and Run does not invent its response.
- Do not replan, judge Goal acceptance, clean or package the whole attempt,
  adopt or publish results, or select the next Goal.

## Procedure

Take the next activated operation, work within its exact boundary, perform the
checks needed for its route, append the result, and follow the selected edge.
Repeat until all activated normal branches reach end or the declared abort
response is complete. Halt as `plan-complete` even when a fail edge was taken;
that status means topology completion only. Run `scripts/append --help` for
the event interface, append with exact Goal and Plan bindings, and use
`scripts/project` and `scripts/validate` only for derived state and ledger
consistency.

## Disposition

The stable result is the immutable linear execution ledger plus its halt fact. Append an
event after each operation, emergency patch, or abort confirmation; never edit
an event. A projection is reconstructible state, not history. The ledger tells
Finish what ran and what happened. It never turns route completion or a local
operation result into final acceptance.

Do not hand-author, patch, reorder, truncate, or replace stable events. Finish
closure actions belong to a later, separately bound append-only ledger; they
are not Run events.
Ordinary use does not require reading the CUE contract or Tool source. Correct
named public omissions or contradictions; do not bypass the contract.
