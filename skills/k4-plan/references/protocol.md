# Plan document protocol

Plan is one immutable operation DAG for one exact Goal. Temporary input states
the falsifiable difference, selected route with supporting and counter
references, operations, optional guarded parallel groups, blockers, and
unknowns.

Each operation carries earlier dependency indices, Goal point and control
identities served, one Goal-authorized tool, executor, complete read/write
positions, permission and resource references, maximum effects, checks,
idempotency, retry ceiling, and recovery. `none:` explicitly marks an empty
boundary.

The contract generates operation identities and coverage. An executable Plan
has operations, covers every Goal point and control, uses only available tools,
has no forward or cyclic dependency, and places no dependency-related nodes in
one parallel group. It contains no actual execution result. Run public
`--help` for exact field names.
