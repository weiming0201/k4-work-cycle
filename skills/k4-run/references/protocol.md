# Run event and projection protocol

Run is an append-only execution ledger for one exact Goal and Plan. A temporary
event is either:

- `operation-result`: one eligible Plan operation's result, outputs, evidence,
  trace, every mapped invariant-control observation, and deferred issues; or
- `halt`: actual stop position, trigger, budget/effect evidence, evidence, and
  resume reference when one exists.

An operation is appended once and only after dependencies pass. A passing
operation has eligibility, outputs, evidence, trace, and passing invariant
observations. Deferred issues are Finding or unknown statements with evidence;
they cannot trigger unplanned work.

No event follows halt. The projection supplies `not-run` for absent Plan
operations and reports the observed execution position. It does not contain
Goal acceptance judgments, terminal-control judgments, or overall completion.
Those belong to Finish. Run public `--help` for exact event fields and command
syntax.
