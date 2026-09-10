---
name: k4-plan
description: Freeze one exact Goal into one selected, finite operation DAG with pass/fail routing. Use after k4-goal and before execution; do not perform operations or revise the Goal.
---

# K4 Plan

Freeze the task-specific control flow that Run will consume.

## Boundary

- Require one exact frozen Goal; otherwise return to `k4-goal`.
- Select tools only from the Goal's frozen available set.
- Search, inspect, and compare alternatives as needed within the Goal boundary.
- For a complex Goal, compare two or three materially different candidate DAGs
  when that comparison improves selection; freeze only the selected Plan and a
  concise selection rationale.
- Every operation has exactly two result edges, `pass` and `fail`. Both may
  point to the same successor. Fork, join, and end are structural positions,
  not semantic result types.
- Findings and unknowns remain annotations. They do not create a third route.
- Do not alter Goal criteria, perform work, record actual results, or repair
  missing authority.

## Stable result

The selected Plan fixes the entry, operation graph, Goal coverage, available
tools, read/write positions, permissions, resources, maximum effects, checks,
and both result edges. All graph edges move forward in topological order. A
change to those decisions requires a new Plan.

## Materialize

Run `scripts/materialize --help` for the public input contract. Give temporary
semantic JSON to the script and bind the exact Goal. The deterministic Tool
creates the stable DAG and its start/fork/join/end projection.

Do not hand-author or patch stable JSON. Ordinary use does not require reading
the CUE contract or Tool source. Correct named public omissions or
contradictions; do not bypass the contract.
