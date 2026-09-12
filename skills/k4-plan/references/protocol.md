# Plan document protocol

Plan is one immutable, finite operation DAG for one exact Goal. Temporary input
states the baseline-to-target difference, selection rationale, selected route
with supporting and counter references, operations, blockers, and unknowns.

Each stable operation belongs to the Tool-derived normal or abort phase and carries Tool-derived join dependencies, Goal point and control
identities served, one Goal-authorized tool, executor, complete read/write
positions, permission and resource references, maximum effects, structured
preconditions, one complete local judgment contract, idempotency, retry ceiling,
structured failure handling, and exactly two result edges: `pass` and `fail`.
Each edge records its later successor operations and why. The two edges may have
the same successors. An empty successor list reaches the virtual end.

A precondition states what must hold, its check entry, and expected state. The
local judgment fixes the operation subject, starting baselines, required actual
outputs and evidence, positive and negative criteria, check entry, judge, and
claim limit. It decides only which operation edge Run follows. Both pass and
fail therefore have positive replay criteria; fail is not an unexamined
catch-all. An independent local judge cannot be the responsible executor.

Failure handling is `none`, `restore`, `compensate`, or `preserve-stop`.
Operations with a possible write or effect cannot use `none`. Restore and
compensate name a stable target, an available Goal Tool, and a check;
preserve-stop names what remains stable and how that state is checked without
inventing a corrective action. Empty operation envelope collections are
canonical and may be omitted from temporary input.

The contract generates normal entries and phases, join dependencies, operation
identities, Goal coverage, and a topology projection. Entry operations are the virtual start projection. Multiple
successors are a fork; multiple exact dependencies are a join; empty successors
are end edges. Every result edge points only forward in topological order, so no
write-back edge or cycle is accepted. Findings and unknowns are annotations,
not control-flow results.

An executable Plan has no blocker, covers every Goal point and control, and
keeps every operation's tool, permissions, read/write positions, resources,
and maximum effects within the Goal execution envelope. An independent judge
cannot also be the responsible executor for the point or control it judges.
The Plan contains no execution result. Run `scripts/materialize --help` for
exact input fields.

`on_abort` is global to the Plan. It either selects `preserve-only`, with no
abort operations, or identifies one abort-phase entry whose finite pass/fail
route is activated only after an explicit abort confirmation. Edges never
cross between normal and abort phases. Abort operations may apply controls but
cannot claim the original Goal acceptance points.
