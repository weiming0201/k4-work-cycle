---
name: k4-finish
description: Close one halted Run by performing authorized final verification and closure, judging the frozen Goal, and settling actual effects into the shared Account and completion report. Use after k4-run; do not repair product semantics, rewrite history, replan, adopt, publish, or select the next Goal.
---

# K4 Finish

Turn one bounded dynamic attempt back into a clean, judged, and recoverable
static state.

## Mandate

Finish alone performs the Goal-authorized closure of one halted Run: final
verification, acceptance judgment, deterministic projection regeneration,
cleanup, resource release, authorized rollback or compensation, local
packaging, whole-attempt reporting, and settlement into the Account. The Run
ledger remains the authority for process history.

## Policy

- Bind the exact opening Account, Goal, Plan, and halted Run ledger. Follow the
  ledger's evidence references when closure needs more detail; never rewrite
  its events.
- Record every closure action first in the Finish append-only closure ledger,
  bound to the opening Account, Goal, Plan, and halted Run projection. Perform
  only actions inside Goal's exact closure policy. Final tests,
  deterministic metadata or Manifest regeneration, cleanup, resource release,
  rollback, compensation, and local packaging are valid here when frozen in
  that authority. Product behavior repair and replanning are not.
- End closure work by appending one explicit `halt` event. It is not a closure
  action, consumes no action allowance, and makes the ledger reject every later
  event. An open ledger remains recoverable but cannot be settled; even a
  zero-action closure requires its halt.
- Reason, inspect, search, test, and compare as needed for closure. Record the
  exact Goal-declared judge for each acceptance point; this responsibility is
  not automatically an independent audit.
- Judge every acceptance point and terminal control from bounded evidence. A
  completed route or successful local Run check does not by itself prove Goal
  acceptance.
- Preserve the Account's subject, boundary, and lenses. Settle every predecessor
  item as retained, changed, or retired, and add new facts only inside a
  declared lens.
- Attribute deviations only as far as evidence supports: execution to Run,
  transition design to Plan, target or audit model to Goal, and factual
  baseline to Observe. Attribution is judgment, not repair authority.
- Do not append Run events, alter Goal or Plan, adopt or publish results, or
  select the next Goal.
- Account and judgment evidence may come only from sources already present in
  the opening Account, actual Run evidence, or actual Finish closure evidence.
  Newly discovered external evidence waits for the next Observe.

## Procedure

Read the complete Run ledger and current result surface. For each authorized
closure action, run `scripts/append --help`, perform and append that action.
Append the terminal halt after the last action, then project or validate the
closure ledger. Judge the Goal only after closure work is halted and account
for direct and derivative effects.
Aggregate actual and not-run operations, local results, findings, unknowns,
emergency patches, halt, abort response, residual effects, disposition, and
incomplete work. Run `scripts/materialize --help`, supply only the semantic
settlement, and bind the exact Account, Goal, Plan, Run projection, Run ledger,
and closure ledger. The Tool derives
the operation summary, ledger head, attempt result, lens index, and stable
document structure.

## Disposition

The stable result is the immutable closure ledger plus one completion report
and one updated Account as two projections of the same settlement. A
non-passing attempt may still close
cleanly and remain recoverable; a passing attempt is only a locally accepted
package until separate authority adopts or publishes it. The next Observe may
consume the settled Account. Finish does not expose or select that next Goal.

Do not hand-author or patch stable JSON. Ordinary use does not require reading
the CUE contract or Tool source. If the Tool refuses input, correct the
reported public field or relation; do not bypass the contract.
