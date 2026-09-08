# K4 Work Cycle Skills

This Resource provides four peer Agent Skills:

- `k4-align`: reconcile a bounded current situation and expose possible next
  Goal inputs;
- `k4-goal`: freeze selected Align items as result acceptance, execution, and
  control contracts;
- `k4-plan`: freeze one guarded operation DAG for one exact Goal;
- `k4-run`: attempt one exact Plan and freeze operation, acceptance, and
  control results.

Their dependency is intentionally asymmetric:

```text
Align [optional exact Run binding]
  -> Goal [exact Align binding]
  -> Plan [exact Goal binding]
  -> Run  [exact Goal and Plan bindings]
  -> Align
```

[`DESIGN.md`](./DESIGN.md) defines the shared boundary. Each Skill contains its
own Rust binary source under `scripts/`; [`kernel`](./kernel) provides only
shared deterministic parsing, validation, hashing, binding, ID derivation, and
atomic output code.

Build without writing into the Resource tree:

```text
CARGO_TARGET_DIR=<external-target-dir> cargo build --offline --manifest-path kernel/Cargo.toml
```

Run the end-to-end contract harness with:

```text
CARGO_TARGET_DIR=<external-target-dir> cargo test --offline --manifest-path kernel/Cargo.toml
```

Mechanical
success proves the declared schemas and bindings only. It does not prove
semantic sufficiency, external authority, evidence truth, or wise action.
