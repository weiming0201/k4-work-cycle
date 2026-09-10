---
name: k4-plan
description: Freeze one exact Goal into a single-use operation DAG with explicit dependencies, tools, paths, permissions, effects, checks, concurrency guards, and recovery. Use after k4-goal and before execution; do not perform operations or revise the Goal.
---

# K4 Plan

Use this Skill only to freeze the permitted transition from the Goal baseline
to its predicted terminal state.

## Boundary

- Require one exact frozen Goal; otherwise return to `k4-goal`.
- Select tools only from the Goal's frozen available set.
- Give every operation explicit dependencies, served Goal points and controls,
  executor, readable and writable positions, permissions, resources, maximum
  effects, pre/post checks, retry ceiling, and recovery.
- Treat absent dependency information as unknown concurrency. Parallelism
  exists only in an explicit guarded group without a dependency path.
- Do not alter Goal criteria, perform work, record actual results, or repair
  missing authority.

## Form the semantic input

State one falsifiable baseline-to-target difference, selected route, supporting
evidence, and counterevidence. Then define the operation DAG. Use an explicit
`none:` reference for an intentionally empty boundary; silence is not a
boundary. Record blockers and unknowns instead of hiding them in an operation.

The Plan must make Run simpler: after dependency and guard checks, each node
already fixes what may be read, written, called, affected, checked, retried,
and recovered. A change to any of those decisions requires a new Plan.

## Materialize

Run `scripts/materialize --help` before authoring input. Give temporary semantic
JSON to the script and bind the exact Goal. The deterministic Tool creates an
absent stable DAG.

Do not hand-author or patch stable JSON. Ordinary use does not require reading
the CUE contract or Tool source. Correct named public omissions or
contradictions; do not bypass the contract.
