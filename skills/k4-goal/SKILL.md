---
name: k4-goal
description: Freeze one exact Align selection into a single-use contract for the current baseline, predicted terminal state, audit points, available tools, authority, resources, controls, and stop conditions. Use before planning a goal-scale attempt; do not choose operations or execute work.
---

# K4 Goal

Use this Skill only to freeze what one attempt must achieve and how its terminal
state will be judged.

## Boundary

- Bind one exact Align and select only its `goal-candidate` items.
- Freeze the current baseline, predicted terminal state, evidence cutoff,
  acceptance points, bounded judges, available tools, authority, resources,
  budget, maximum effects, controls, and all stop outcomes.
- Keep acceptance about the resulting state and control about execution
  variables. Neither is an operation.
- Do not choose an implementation route, form a DAG, execute work, admit
  post-cutoff evidence, or revise a frozen Goal.

## Form the semantic input

Select the exact Goal-candidate item IDs from the bound Align. State the
objective, target, source and baseline references, evidence cutoff, scope,
non-goals, blockers, and unknowns.

For each acceptance point state what is observable, the conditions and window,
the expected value, what would falsify it, how evidence is sampled and
compared, the required evidence, and a bounded judge. A judge is self,
independent agent, script, or human; its kind never expands its claim limit.

Separately state every execution control: controlled variable, allowed domain,
forbidden drift, required trace and evidence, check method, invariant or
terminal timing, bounded judge, and non-pass response.

Freeze the execution envelope: authorization and its claim limit, available
Tools, resources, budget, maximum effects, distinct completed, paused, failed,
and cancelled stops, and the incomplete deliverable. These are limits on a
later attempt, not operations.

## Materialize

Write only a temporary semantic JSON input, then invoke:

```text
scripts/materialize --input <semantic-input.json> --output <absent-goal.json> --bind align=<align.json>
```

The script calls the shared deterministic Tool with this Skill's CUE contract.
Any semantic change requires a new output file. Do not hand-author or patch the
stable Goal.

Do not read `assets/protocol.cue`, the shared Tool, or other implementation
source before or during normal use. If materialization refuses the input,
correct the stated semantic omission or contradiction from its error and this
Skill; do not reverse-engineer the mechanical contract.
