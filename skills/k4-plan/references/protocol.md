# Plan document protocol

Plan is one immutable operation DAG for one exact Goal.

The temporary semantic input contains:

- one falsifiable `difference` and selected `route` with supporting and
  counter references;
- `operations`, where `depends_on_indices` names earlier array positions;
- for each operation: Goal point and control IDs, one Goal-authorized
  `tool_ref`, responsible executor, complete `read_refs` and `write_refs`,
  permission and resource references, maximum side effects, pre- and
  post-checks, idempotency, retry ceiling, and recovery;
- optional `parallel_groups` naming operation indices, a reason, and concrete
  guards;
- explicit blockers and unknowns.

Use a literal explanatory reference such as `none:no-write` when an operation
has no write position; an empty list is not an explicit boundary.

The contract replaces indices with generated operation identities and derives
Goal acceptance and control coverage. An executable Plan has at least one
operation, covers every Goal point and control, uses only Goal-authorized
Tools, has no forward or cyclic dependency, and never places dependency-related
operations in one parallel group.

Nonempty blockers yield `not-executable`; otherwise nonempty unknowns yield
`unknown`; otherwise the Plan is `executable`. Actual execution and results
are not part of this document.
