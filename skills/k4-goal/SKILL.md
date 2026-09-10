---
name: k4-goal
description: Select and freeze one exact Goal from the current Observe Account, including acceptance, authority, tools, resources, and controls. Use before k4-plan; do not choose operations or execute work.
---

# K4 Goal

Freeze what one attempt must achieve and how Finish can judge it.

## Boundary

- Require one exact current Observe Account; otherwise return to `k4-observe`.
- Select only explicit `goal-candidate` items from that Account.
- Search and inspect further evidence as needed without changing the Observe
  Account in place.
- For a complex situation, compare two or three materially different candidate
  Goals when that improves selection; freeze only the selected Goal and a
  concise selection rationale.
- Freeze baseline, target, cutoff, acceptance, bounded judges, tools, authority,
  resources, budget, maximum effects, and controls.
- Acceptance describes the resulting state. Controls describe bounded execution
  variables. Neither is an operation.
- Do not choose a route, form a DAG, execute work, admit post-cutoff evidence,
  or revise a frozen Goal.

## Stable result

The selected Goal contains its Observe sources, objective, target, baseline,
scope, acceptance points, controls, authority, available tools, resources,
budget, maximum effects, blockers, and unknowns. Unknowns remain annotations;
only a blocker prevents freezing.

## Materialize

Run `scripts/materialize --help` for the public input contract. Give temporary
semantic JSON to the script and bind the exact Observe Account. The
deterministic Tool creates the stable Goal. Any semantic change requires a new
Goal.

Do not hand-author or patch stable JSON. Ordinary use does not require reading
the CUE contract or Tool source. Correct named public omissions or
contradictions; do not bypass the contract.
