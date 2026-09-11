# Plan document protocol

Plan is one immutable, finite operation DAG for one exact Goal. Temporary input
states the baseline-to-target difference, selection rationale, selected route
with supporting and counter references, operations, blockers, and unknowns.

Each stable operation belongs to the Tool-derived normal or abort phase and carries Tool-derived join dependencies, Goal point and control
identities served, one Goal-authorized tool, executor, complete read/write
positions, permission and resource references, maximum effects, checks,
idempotency, retry ceiling, recovery, and exactly two result edges: `pass` and
`fail`. Each edge records its later successor operations and why. The two edges
may have the same successors. An empty successor list reaches the virtual end.

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
