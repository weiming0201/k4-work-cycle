---
name: k4-goal
description: Freeze one bounded objective into a versioned set of jointly sufficient prediction and control acceptance points before planning or execution. Use when completion criteria, evidence, authority, side effects, stop states, or incomplete delivery must be explicit; do not use it to order or execute work.
---

# K4 Goal

Form the acceptance contract for one bounded objective. Read the input only as
evidence; do not turn technical reach, a source statement, or a prior result
into authorization or fact.

## Result boundary

The standalone result is one digest-addressed Goal with:

- an exact target, desired outcome, Baseline, source cutoff, scope, non-goals,
  authorization reference, resources, budget, maximum side effects, stop
  conditions, incomplete-delivery rule, and explicit unknowns;
- a set of acceptance points whose conjunction is sufficient to decide whether
  this Goal was achieved;
- every point classified as exactly one of `prediction` or `control`.

Goal does not choose a route, order points, execute work, validate actual
results, grant permission, or adopt an output. Those responsibilities cannot be
repaired by optimistic wording in this result.

## Acceptance points

Give every point a stable `point_id`.

A `prediction` point freezes the result contract before the result of the
target attempt is observed. State the observable, conditions, observation
window, expected result or range, falsifier, stable result-contract source,
comparison method, and sampling rule. It passes only after a real attempt
produces an actual-result reference that can be compared with this frozen
contract. A prediction is not a checklist item: it must affect the Goal verdict,
and its contrary must be expressible.

A `control` point freezes how the work must be controlled. State the required
method, allowed variations, forbidden drift, required trace, checking method,
and non-pass route. It passes only after the actual method and trace can be
compared with this contract. Control conformance does not prove the target
result correct.

If one statement asks both whether a result occurred and whether a method was
preserved, split it. Evidence and checker mechanisms do not create a third
acceptance kind.

## Workflow

1. Freeze the target identity, boundary, desired outcome, Baseline, source
   cutoff, authorization claim limit, resources, budget and maximum side
   effects.
2. Classify material inputs as fact, source statement, inference, preference or
   unknown, preserving a source reference where one exists.
3. Form prediction and control points. Challenge their conjunction for
   sufficiency, contradiction, duplication, hidden implementation steps and
   unverifiable language.
4. Define completed, paused, failed and cancelled separately, including what is
   delivered and where work can resume when incomplete.
5. Write a temporary JSON Candidate with the fields enforced by
   `scripts/goal_result.py`. Read [the result contract](references/result-contract.md)
   when authoring that Candidate. Freeze it only through:

   ```text
   python3 scripts/goal_result.py freeze --candidate <candidate.json> --output <absent-result.json> --frozen-at <RFC3339>
   ```

6. Validate a frozen result with:

   ```text
   python3 scripts/goal_result.py validate --result <result.json>
   ```

The Tool proves structure, exclusivity and content identity only. Semantic
sufficiency remains the forming Agent's judgment and must stay `unknown` when
the available evidence cannot support it.

## Revision and stop

Freeze `not-frozen` when a known contradiction or missing decision prevents a
coherent Goal. Freeze `unknown` when the evidence cannot decide whether the Goal
is coherent. Never send either status to Plan as executable input.

Changing a target, boundary, acceptance point or control envelope creates a new
Goal version with `supersedes`; it never edits an earlier result. Existing
Plans, attempts and evidence remain bound to the exact earlier content identity.
