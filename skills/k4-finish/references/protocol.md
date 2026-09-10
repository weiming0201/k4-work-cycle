# Finish document protocol

Finish materializes one closing Account plus a closure report for one exact
halted attempt. It binds the opening Account, Goal, Plan, and exact Run ledger;
the Run projection used for settlement is derived mechanically from that ledger.

The Account core is the same structured observation surface as Observe:
subject, boundary, cutoff, sources, lenses, generated lens index, delta,
current retained/changed/added items, retired predecessors, identities, and
exact predecessor binding. Subject, boundary, and lenses remain unchanged.

Closure is the stage report. It adds one pass/fail judgment for every Goal
acceptance point and terminal control, result disposition, incomplete package,
and exact journal reference. The Tool derives operation counts, actual and
not-run operations, Findings, unknowns, emergency patches, halt, ledger head,
and the attempt result from the derived Run projection. Unknown is an annotation,
not a third routing result.

An attempt passes only when the Run reaches `plan-complete` and every acceptance
point, terminal control, and invariant control passes. A failed operation may
therefore be truthfully recovered by its frozen fail route; operation failure
alone does not replace Goal judgment. A non-passing attempt retains a nonempty
incomplete package.

The complete trace is evidence for a separately authorized external audit.
Finish performs internal reconciliation and terminal judgment; it does not
become an independent auditor by possessing that evidence.

Finish exposes no future Goal candidate and performs no repair, adoption, or
publication. The generated Finish Account is a legal predecessor for the next
Observe. Run public `--help` for exact fields and binding syntax.
