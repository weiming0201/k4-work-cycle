# Run event and projection protocol

Run is an append-only execution ledger for one exact Goal and Plan. A temporary
event is either:

- `operation-result`: one activated Plan operation's `pass` or `fail`, outputs,
  evidence, trace, invariant observations, Findings, and unknowns;
- `emergency-patch`: the one permitted patch attempt for an operation, including
  its script, exact positions, effects, application result, and deferred audit
  material; or
- `abort-confirmed`: one sourced external cancellation or recoverable runtime
  failure fact that stops the normal route and activates the Plan-level abort
  response; or
- `halt`: budget/effect evidence, evidence, and
  resume reference when one exists.

Abort and halt positions and the halt trigger are derived from the ledger. The
patch attempt and verification scope are fixed by the protocol. Empty optional
unknowns and reference collections receive canonical defaults. Patch Findings
are not optional: every emergency patch records at least one actual Finding;
the Tool neither invents Finding text from the reason nor supplies an empty
Finding collection.

An operation is appended once, after it is activated by the Plan and every join
dependency has a response. Its binary result alone selects the frozen successor
edge. Findings and unknowns are annotations and may accompany either result.
Operations that were never activated remain `not-run` in the projection.

One emergency patch may restore an activated normal operation when the Plan omitted a
necessary execution detail. Its only verification scope is resumption of the
original operation; it has no separate systematic test and does not change the
Goal or Plan. Its tools, permissions, read/write positions, resources, and
maximum effects must all remain inside the Goal execution envelope.

An abort response is frozen by Plan as `preserve-only` or a separate finite
abort-phase route. It is never a third result edge, cannot claim Goal
acceptance, and cannot receive an emergency patch. Run only records the abort
fact and executes the declared response.

No event follows halt. `plan-complete` requires every activated normal branch
to reach end and cannot follow abort confirmation. `abort` requires exactly one
confirmation and every activated response branch to reach end. A ledger with
neither terminal event remains open. The projection does
not judge Goal acceptance or terminal controls; those belong to Finish. Run
`scripts/append --help` for exact event fields. A projection is revalidated only
by rederiving it from its exact source ledger through `scripts/validate`.
