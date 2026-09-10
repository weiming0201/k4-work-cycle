---
name: k4-goal
description: Freeze one exact Observe Account selection into a single-use contract for terminal audit points, tools, authority, resources, controls, and stop conditions. Use before planning a goal-scale attempt; do not choose operations or execute work.
---

# K4 Goal

Use this Skill only to freeze what one attempt must achieve and how its terminal
state will be judged.

## Boundary

- Require one exact current Observe Account; otherwise return to `k4-observe`.
- Select only explicit `goal-candidate` items from that Account.
- Freeze baseline, predicted terminal state, cutoff, acceptance, bounded judges,
  tools, authority, resources, budget, maximum effects, controls, four stop
  outcomes, and incomplete deliverable.
- Acceptance describes the resulting state. Controls describe bounded execution
  variables. Neither is an operation.
- Do not choose a route, form a DAG, execute work, admit post-cutoff evidence,
  or revise a frozen Goal.

## Form the semantic input

State selected item identities, objective, target, baseline and source
references, cutoff, scope, non-goals, blockers, and unknowns. Each acceptance
point states observable, conditions, window, expected value, falsifier,
sampling and comparison, required evidence, and bounded judge. Each control
states the controlled variable, allowed domain, forbidden drift, required
trace and evidence, check method, invariant or terminal timing, bounded judge,
and non-pass response.

The execution envelope states authorization and claim limit, available tools,
resources, budget, maximum effects, distinct completed/paused/failed/cancelled
conditions, and incomplete deliverable.

## Materialize

Run `scripts/materialize --help` before authoring input. Give temporary semantic
JSON to the script and bind the exact Observe Account. The deterministic Tool
creates an absent stable Goal. Any semantic change requires a new Goal.

Do not hand-author or patch stable JSON. Ordinary use does not require reading
the CUE contract or Tool source. Correct named public omissions or
contradictions; do not bypass the contract.
