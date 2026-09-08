---
name: k4-plan
description: Turn one exact frozen K4 Goal into one selected route and guarded operation DAG that covers its acceptance and control contracts. Use after k4-goal; do not use it to change Goal contracts, execute operations, or claim results.
---

# K4 Plan

Plan defines the operation dependency relation for attempting one exact Goal.
Goal owns what must pass and remain controlled; Plan owns the route, operations,
dependencies, and explicit parallel possibilities.

## Input and boundary

Input one `k4-goal-result/v2` with `status=frozen`. Define a flat list of
operations. Each operation declares earlier dependencies, the Goal acceptance
points it helps satisfy, the Goal controls it obeys, its Action or Tool,
responsible executor, inputs, outputs, permissions, resources, maximum effects,
checks, retry ceiling, and recovery.

An operation may satisfy several acceptance points; several operations may
satisfy one point; an enabling operation may satisfy none. An executable Plan
must collectively cover every acceptance point and every control contract.
Plan never copies or alters their criteria.

Dependencies express necessary precedence. Lack of a dependency does not grant
parallel execution. A parallel group must identify its operations and state why
their writes, resources, evidence, permissions, and effects can coexist. Plan
stores the selected route, not discarded exploration or execution results.

## Stable result

Read [the result contract](references/result-contract.md), author only its
temporary semantic input, then call this generator from the Skill root:

```text
cargo run --offline --manifest-path ../../kernel/Cargo.toml --bin k4-plan-result -- generate --goal <goal-result.json> --input <semantic-input.json> --output <absent-result.json>
```

Rust validates the Goal, generates the exact binding, operation IDs, dependency
IDs and reverse coverage indexes, checks the DAG and guarded parallel groups,
and creates time, status, digest, canonical bytes, and absent output. Do not
hand-author or patch stable JSON.

Use a blocker for a known missing execution condition and an unknown when
available evidence cannot decide it. Run may consume only
`status=executable`.
