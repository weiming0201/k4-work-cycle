---
name: k4-plan
description: Freeze one exact Goal into a single-use operation DAG with explicit dependencies, tools, readable and writable positions, permissions, resources, checks, concurrency guards, and recovery. Use after k4-goal and before execution; do not perform the operations or revise the Goal.
---

# K4 Plan

Use this Skill only to freeze the permitted transition from the Goal baseline
to its predicted terminal state.

## Boundary

- First locate one exact frozen Goal. If none exists or selection is
  ambiguous, stop and route to `k4-goal`; do not draft a Plan.
- Bind one exact frozen Goal.
- Select Tool references only from the Goal's `available_tools`.
- Give every operation explicit dependencies, acceptance and control mappings,
  responsible executor, readable and writable positions, permission and
  resource references, maximum effects, checks, retry ceiling, and recovery.
- Treat missing dependency edges as unknown concurrency. Parallelism exists
  only in an explicit guarded group with no dependency path.
- Do not change Goal audit points, execute an operation, record actual results,
  or repair missing authority.

## Form the semantic input

State the falsifiable difference between baseline and target, the selected
route, supporting evidence, and counterevidence. Then define the operation DAG.
For every operation provide:

- earlier operation indices that it depends on;
- Goal acceptance points and controls it serves;
- one Tool already available in the Goal and its responsible executor;
- complete readable and writable positions, permissions, resources, and
  maximum effects;
- pre-checks, post-checks, idempotency, retry ceiling, and recovery position.

Use an explicit `none:` reference when a boundary is intentionally empty;
silence is not a boundary. Declare parallel groups only when their operations
have no dependency path, and state both the reason and concrete guards. Record
blockers and unknowns rather than inventing an operation that hides them.

## Materialize

Before authoring the temporary input, run `scripts/materialize --help` and use its output as the only field vocabulary.

Write only a temporary semantic JSON input, then invoke:

```text
scripts/materialize --input <semantic-input.json> --output <absent-plan.json> --bind goal=<goal.json>
```

The script calls the shared deterministic Tool with this Skill's CUE contract.
Any route, operation, dependency, Tool, or boundary change requires a new Plan.
Do not hand-author or patch the stable DAG.

Do not read `assets/protocol.cue`, the shared Tool, or other implementation
source before or during normal use. If materialization refuses the input,
correct the stated semantic omission or contradiction from its error and this
Skill; do not reverse-engineer the mechanical contract.
