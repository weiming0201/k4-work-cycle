# Finish document protocol

Finish materializes one closing Account plus a closure report for one exact
halted attempt. It binds the opening Account, Goal, Plan, and exact Run ledger;
the Run projection used for settlement is derived mechanically from that ledger.

The caller supplies a closing semantic delta (updates, additions, and
retirements), actual acceptance and terminal-control judgments, result
disposition, and failure-only incomplete content. The Tool carries every
unmentioned predecessor forward and derives sources, continuity, judge refs,
and canonical empty/null fields.

Each update identifies one opening Account item and supplies its replacement
item; an addition supplies a new item; a retirement identifies one opening item
and its evidence. The same predecessor cannot occur in multiple updates or in
both an update and a retirement, and every update predecessor must exist in the
opening Account. These raw relations are checked before any projection so no
caller meaning can be collapsed or discarded.

An item declares `lens`, epistemic kind, state, statement, evidence, and route.
`route_ref` is nonempty only for `external` and is otherwise absent in semantic
input or canonical null in the stable document. A closing Finish Account cannot
contain `goal-candidate`; only a later Observe can expose a future Goal
candidate. If the bound Goal has no terminal controls, omission of
`terminal_control_results` has the unique generated value `[]`; otherwise every
terminal judgment remains required.

The Account core is the same structured observation surface as Observe:
subject, boundary, cutoff, sources, lenses, generated lens index, delta,
current retained/changed/added items, retired predecessors, identities, and
exact predecessor binding. Subject, boundary, and lenses remain unchanged.

Closure is the stage report. It adds one pass/fail judgment for every Goal
acceptance point and terminal control with the exact judge identity frozen by
Goal, result disposition, incomplete package, and exact journal reference. The
Tool derives operation counts, actual and not-run operations, Findings,
unknowns, emergency patches, halt, ledger head, and the attempt result from the
derived Run projection. Unknown is an annotation, not a third routing result.

For an aborted attempt, closure also derives the confirmation source and
reason, the Plan's response mode, planned and actual abort-response operations,
their pass/fail counts, and residual-effect evidence. Successful response work
does not rewrite the attempt as plan-complete.

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
