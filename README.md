# K4 Work Cycle Agent Extension

This Resource packages five responsibilities over four storage strategies as
peer Agent Skills:

- `k4-observe`: creates the multi-lens opening Account and gap/opportunity report;
- `k4-goal`: freezes one flat mandate of acceptance and operating limits;
- `k4-plan`: freezes forward pass/fail work in an operation DAG;
- `k4-run`: appends operation, emergency-patch, and halt facts to the journal;
- `k4-finish`: reconciles the journal into the closing Account and stage report.

Observe and Finish share the Account storage strategy but remain separate
temporal responsibilities. The retained trace supports later independent audit;
no internal stage becomes that audit by implication.

Read [`WORKFLOW.md`](./WORKFLOW.md) for semantics and
[`DESIGN.md`](./DESIGN.md) for implementation boundaries. See
[`MIGRATION.md`](./MIGRATION.md) only when upgrading a `0.4.1` chain.

## Source layout

```text
WORKFLOW.md
DESIGN.md
MIGRATION.md
README.md
manifest.cue
manifest.json
tools/stable-result
tools/migrate-0.4.1-to-0.5.0
skills/
  k4-observe/{SKILL.md,assets/,references/,scripts/}
  k4-goal/{SKILL.md,assets/,references/,scripts/}
  k4-plan/{SKILL.md,assets/,references/,scripts/}
  k4-run/{SKILL.md,assets/,references/,scripts/}
  k4-finish/{SKILL.md,assets/,references/,scripts/}
tests/conformance.py
tests/fixtures/0.4.1/
```

The only fixed executable dependency is CUE `v0.17.1`. The shared Tool is
stage-neutral; every Skill supplies its own CUE contract.

## Mechanical interface

Skill-local scripts are the public entrypoints. Observe, Goal, Plan, and Finish
materialize immutable documents. Run appends one event, projects its ledger,
and validates either the ledger or its derived projection. Every stable JSON or
JSONL output is Tool-generated; semantic input remains a temporary work product.

Release `0.5.0` makes Goal execution bounds and judge identity mechanically
explicit. Existing `0.4.1` chains are not edited in place. Migrate an exact
chain with `tools/migrate-0.4.1-to-0.5.0 --help`; the Tool requires an explicit
policy for the new authority and judge fields, re-materializes every supplied
artifact, rebuilds the Run hash chain, and records old and new file digests.

Run the source conformance suite from the Resource root:

```text
python3 tests/conformance.py
```

Tests use isolated temporary directories and include one generated `0.4.1`
chain as a migration fixture. Mechanical validation proves only
declared structure, bindings, write semantics, and transitions. It does not
prove evidence truth, Goal or Plan sufficiency, or external authorization.

Publishing this Resource does not install it. Runtime projection and
fresh-session discovery belong to a later, separately authorized Goal.
