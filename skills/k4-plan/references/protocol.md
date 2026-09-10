# Plan document protocol

Plan is one immutable, finite operation DAG for one exact Goal. Temporary input
states the baseline-to-target difference, selection rationale, selected route
with supporting and counter references, entry operations, operations, blockers,
and unknowns.

Each operation carries earlier dependency indices, Goal point and control
identities served, one Goal-authorized tool, executor, complete read/write
positions, permission and resource references, maximum effects, checks,
idempotency, retry ceiling, recovery, and exactly two result edges: `pass` and
`fail`. Each edge records its later successor operations and why. The two edges
may have the same successors. An empty successor list reaches the virtual end.

The contract generates operation identities, Goal coverage, and a topology
projection. Entry operations are the virtual start projection. Multiple
successors are a fork; multiple exact dependencies are a join; empty successors
are end edges. Every result edge points only forward in topological order, so no
write-back edge or cycle is accepted. Findings and unknowns are annotations,
not control-flow results.

An executable Plan has no blocker, covers every Goal point and control, and uses
only Goal-authorized tools. It contains no execution result. Run
`scripts/materialize --help` for exact input fields.
