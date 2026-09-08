---
name: k4-goal
description: Freeze selected K4 Align goal-candidate items into one bounded result-acceptance set, execution envelope, and control set before planning. Use after k4-align; do not use it to select a route, order work, execute operations, or adopt results.
---

# K4 Goal

Goal defines what one bounded increment must produce and what its execution
must remain within. It does not describe how to do the work.

## Input and boundary

Input exactly one `k4-align-result/v1` and select one or more items routed as
`goal-candidate`. Freeze:

- acceptance points for observable result claims;
- control contracts for execution variables that must remain in bounds; and
- one execution envelope for authority, resources, budget, effects, stopping,
  and incomplete delivery.

Every acceptance point states its conditions, observation window, expected
result, falsifier, comparison method, evidence, and judge. Every control states
its controlled variable, allowed domain, forbidden drift, trace, check method,
check timing, non-pass route, evidence, and judge. `invariant` means the control
must be checked while governed operations run; `terminal` means it is checked
at the final boundary.

Acceptance judges the result. Control keeps execution within a declared
domain. The execution envelope bounds the whole attempt. None selects a route,
operation, dependency, or actual executor.

## Stable result

Read [the result contract](references/result-contract.md), author only its
temporary semantic input, then call this generator from the Skill root:

```text
cargo run --offline --manifest-path ../../kernel/Cargo.toml --bin k4-goal-result -- generate --align <align-result.json> --input <semantic-input.json> --output <absent-result.json>
```

Rust verifies the selected Align items and generates the exact binding,
acceptance and control IDs, time, status, digest, canonical bytes, and absent
output. Do not hand-author or patch stable JSON.

Use a blocker for a known reason the Goal cannot freeze and an unknown for
missing evidence that prevents judgment. Plan may consume only
`status=frozen`.
