---
name: k4-plan
description: Turn one frozen K4 Goal into a guarded, executable acceptance-point dependency graph without changing its criteria. Use after k4-goal when reaching the points requires multiple dependent operations, explicit permissions or resources, failure routing, recovery, or controlled parallelism; do not use it to execute or adopt work.
---

# K4 Plan

Build the execution contract for one exact frozen Goal. The Goal owns what must
pass. Plan owns when each acceptance point may run and how an executor can try
to reach it.

## Required input and result

Input one `k4-goal-result/v1` whose status is `frozen`, plus the frozen
difference between its Baseline and desired outcome, relevant evidence, and the
currently known Ability, Tool, permission and resource references.

The standalone result is one digest-addressed Plan that:

- binds the exact Goal file and content identity;
- contains every Goal `point_id` exactly once and no additional acceptance
  point;
- orders those point identities as a guarded DAG;
- attaches a complete minimum-operation execution contract to every point;
- returns `executable`, `not-executable` or `unknown` without claiming success,
  current action authority, validation or adoption.

Never copy or restate a Goal criterion. If a criterion is missing or ambiguous,
stop and request a new Goal version.

## Workflow

1. Verify the Goal identity, digest and `frozen` status. Freeze the actual
   difference and all still-plausible routes, including stopping or preserving
   the current state when relevant. Reject convenient alternatives that require
   broader authority or effects without stating that difference.
2. Select one route under the Goal's decision boundary. Preserve supporting,
   counter and unknown evidence; selection does not create permission or prove
   success.
3. Create exactly one Plan node for each Goal `point_id`. Within the node,
   expand the work into minimum operations. Each operation states inputs,
   action, outputs, responsibility, Ability or Tool references, internal
   dependencies, ordering and idempotency, permission references, resources,
   maximum side effects, pre/post checks, retry limit, recovery, next entrance
   and stop conditions.
4. Add only necessary point-to-point dependencies. Each edge states why the
   predecessor must pass first, what must remain unchanged while crossing the
   edge, and what happens when the predecessor is `Finding`, `unknown` or not
   run.
5. Check that the point graph and every node's operation graph are acyclic.
   Absence of a dependency does not grant parallel execution; declare a
   parallel group only when writes, resources, evidence, permissions and side
   effects can coexist.
6. Judge contract-level executability. `executable` means the complete contract
   can be consumed when its declared premises are rechecked. It does not mean a
   node currently has permission or resources. Use `not-executable` for a known
   blocking defect and `unknown` when available evidence cannot decide.
7. Write a temporary JSON Candidate with the fields enforced by
   `scripts/plan_result.py`. Read [the result contract](references/result-contract.md)
   when authoring that Candidate. Freeze it only through:

   ```text
   python3 scripts/plan_result.py freeze --goal <goal-result.json> --candidate <candidate.json> --output <absent-result.json> --frozen-at <RFC3339>
   ```

8. Validate a frozen result against the same Goal with:

   ```text
   python3 scripts/plan_result.py validate --goal <goal-result.json> --result <plan-result.json>
   ```

The Tool proves exact Goal binding, point coverage, graph structure and content
identity only. It cannot prove that route selection is wise, external
references are true, current action authority exists or execution will succeed.

## Execution and revision boundary

Before a node runs, the execution system must recheck that all predecessors are
`pass`, all edge guards still hold, and the current Baseline, inputs,
permissions, resources and side-effect ceiling remain valid. A non-pass result
blocks dependent nodes; unrelated nodes may continue only within their own
still-valid contracts.

Actual operations, results, failures and recovery enter external State and
append-only History referencing the exact Plan digest. They never append to or
rewrite the Plan. A changed Goal or route requires a new Plan version; retries
are new attempts against an unchanged version.
