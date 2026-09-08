---
name: k4-run
description: Attempt only the eligible operations of one exact executable K4 Plan and freeze separate operation, acceptance, and control results. Use after k4-plan; do not use it to replan, broaden authority, reuse old evidence silently, adopt outputs, or choose the next Goal.
---

# K4 Run

Run attempts one exact Goal through one exact Plan. It preserves what actually
ran, what result criteria passed, what controls held, and where a non-completed
attempt can resume.

## Input and boundary

Input one frozen `k4-goal-result/v2` and one executable
`k4-plan-result/v2` bound to those exact Goal bytes. Before each operation,
recheck its dependencies, inputs, permissions, resources, pre-checks, budget,
maximum effects, and applicable invariant controls. Invoke only its declared
`action_ref`; a changed action, dependency, or route requires a new Plan.

Record separately and exactly once:

- every Plan operation and its eligibility, output, evidence, and trace;
- every Goal acceptance point and its actual/comparison evidence; and
- every Goal control and its actual/trace/comparison evidence.

Use `pass`, `Finding`, `unknown`, or `not-run`. An operation cannot run after a
non-pass dependency. Acceptance cannot pass until all mapped operations pass.
An invariant control cannot remain `not-run` after a governed operation runs;
a terminal control may remain pending until the terminal check.

Run does not adopt output or choose what happens next. It does not silently
carry evidence from an older Run. Its stable result may become input to a new
Align.

## Stable result

Read [the result contract](references/result-contract.md), author only its
temporary semantic input from actual execution evidence, then call this
generator from the Skill root:

```text
cargo run --offline --manifest-path ../../kernel/Cargo.toml --bin k4-run-result -- generate --goal <goal-result.json> --plan <plan-result.json> --input <semantic-input.json> --output <absent-result.json>
```

Rust validates both predecessors and their binding, copies control timing from
Goal, checks complete coverage and dependency/control rules, derives the
aggregate result, and creates time, bindings, digest, canonical bytes, and
absent output. Do not hand-author or patch stable JSON.

Stop instead of invoking an ineligible operation. Every non-completed stop must
retain an exact resume reference.
