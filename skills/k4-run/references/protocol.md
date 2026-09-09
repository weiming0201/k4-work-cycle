# Run event and projection protocol

Run is an append-only event ledger for one exact Goal and Plan.

Each temporary input is exactly one event:

- `operation-result`: one Plan operation, result `pass`, `Finding`, or
  `unknown`, eligibility, outputs, evidence, trace, and one check for every
  invariant Goal control mapped to that operation, plus every potential
  unresolved issue observed during the increment;
- `acceptance-result`: one Goal point, actual value, comparison, evidence, and
  bounded result;
- `control-result`: one terminal-timed Goal control with actual value, trace,
  comparison, evidence, and bounded result;
- `stop`: actual stop state, budget and side-effect evidence, and a null
  resume reference only for completion.

`not-run` is never appended as an event. It is the projection of an absent
operation or judgment.

An operation result may be appended only once and only after every dependency
has a prior `pass` event. A `pass` operation has eligibility, output,
evidence, and trace references. Every invariant control mapped to an attempted
operation has an embedded check; a non-pass check prevents the operation from
passing.

Every `operation-result` contains `deferred_issues`, including an explicit
empty list when none were observed. Each entry records only `Finding` or
`unknown`, its statement, and evidence references. Run must not investigate,
repair, prioritize, route, or act on those issues; a later Align consumes them
as evidence. An issue that proves the current operation drifted prevents that
operation from passing. An out-of-scope issue may be deferred without changing
an otherwise evidenced result.

Acceptance may pass only after every mapped operation has passed. A terminal
control may be recorded only for a terminal-timed Goal control. Every entity
has at most one final result event. No event follows `stop`.

The projection lists every Plan operation, Goal point, and Goal control,
supplying `not-run` for missing entries. It aggregates repeated invariant
checks without discarding their observations. Its result is `Finding` when
any result is a Finding, otherwise `unknown` while any result is unknown or
not run, otherwise `pass`. `pass` and `stop_state=completed` coincide.
Every other stop state has a nonempty resume reference.
