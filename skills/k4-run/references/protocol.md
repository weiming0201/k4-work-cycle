# Run event and projection protocol

Run is an append-only execution ledger for one exact Goal and Plan. A temporary
event is either:

- `operation-result`: one activated Plan operation's `pass` or `fail`, outputs,
  evidence, trace, invariant observations, Findings, and unknowns;
- `emergency-patch`: the one permitted patch attempt for an operation, including
  its script, exact positions, effects, application result, and deferred audit
  material; or
- `halt`: actual stop position, trigger, budget/effect evidence, evidence, and
  resume reference when one exists.

An operation is appended once, after it is activated by the Plan and every join
dependency has a response. Its binary result alone selects the frozen successor
edge. Findings and unknowns are annotations and may accompany either result.
Operations that were never activated remain `not-run` in the projection.

One emergency patch may restore an activated operation when the Plan omitted a
necessary execution detail. Its only verification scope is resumption of the
original operation; it has no separate systematic test and does not change the
Goal or Plan.

No event follows halt. `plan-complete` requires every activated branch to reach
end. `blocked` and `cancelled` preserve exceptional stops. The projection does
not judge Goal acceptance or terminal controls; those belong to Finish. Run
`scripts/append --help` for exact event fields.
