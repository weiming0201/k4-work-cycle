---
name: k4-finish
description: Settle one halted Run ledger into the shared Account and a bounded completion report. Use after k4-run; do not repair the attempt, alter its Goal or Plan, adopt or publish results, select the next Goal, or claim independent audit.
---

# K4 Finish

Close one bounded attempt by posting its actual Run ledger to the same general
ledger that Observe opened.

## Boundary

- Bind the exact opening Account, Goal, Plan, and halted Run projection. Treat
  the Run ledger as the primary process evidence and follow its evidence
  references only when the settlement needs more detail.
- Preserve the Account subject, boundary, and observation lenses. Account for
  every predecessor item as retained, changed, or retired; new facts may be
  added only inside an already declared lens.
- Judge every Goal acceptance point and terminal control from bounded evidence.
  A completed Plan route does not by itself prove that the Goal passed.
- Aggregate actual and not-run operations, pass/fail results, Findings,
  unknowns, emergency patches, halt, result disposition, and incomplete work.
- Do not repair, replan, append Run events, adopt or publish a result, or expose
  the next Goal. The next Observe decides how the settled Account changes the
  opportunity inventory.

## Produce the settlement

Form the current Account from the opening Account and the actual attempt delta.
Then provide one pass/fail judgment for every acceptance point and terminal
control. Unknowns remain explicit annotations and do not become a third result.

The deterministic output derives the operation summary, Run Findings and
unknowns, halt, attempt result, ledger head, and lens index. The closing report
and updated Account are two projections of one settlement, not independent
stores.

## Materialize

Run `scripts/materialize --help`, supply temporary semantic JSON, and bind the
exact opening Account, Goal, Plan, and halted Run projection. The deterministic
Tool creates the stable Finish output. Do not hand-author or patch stable JSON.

Ordinary use does not require reading the CUE contract or Tool source. If the
Tool refuses input, correct the reported public field or relation; do not
bypass the contract.
