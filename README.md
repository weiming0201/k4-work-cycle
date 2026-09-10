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
[`DESIGN.md`](./DESIGN.md) for implementation boundaries.

## Source layout

```text
WORKFLOW.md
DESIGN.md
README.md
manifest.cue
manifest.json
tools/stable-result
skills/
  k4-observe/{SKILL.md,assets/,references/,scripts/}
  k4-goal/{SKILL.md,assets/,references/,scripts/}
  k4-plan/{SKILL.md,assets/,references/,scripts/}
  k4-run/{SKILL.md,assets/,references/,scripts/}
  k4-finish/{SKILL.md,assets/,references/,scripts/}
tests/conformance.py
```

The only fixed executable dependency is CUE `v0.17.1`. The shared Tool is
stage-neutral; every Skill supplies its own CUE contract.

## Mechanical interface

Skill-local scripts are the public entrypoints. Observe, Goal, Plan, and Finish
materialize immutable documents. Run appends one event and projects its ledger.
Every stable JSON or JSONL output is Tool-generated; semantic input remains a
temporary work product.

Run the source conformance suite from the Resource root:

```text
python3 tests/conformance.py
```

Tests use isolated temporary directories. Mechanical validation proves only
declared structure, bindings, write semantics, and transitions. It does not
prove evidence truth, Goal or Plan sufficiency, or external authorization.

Publishing this Resource does not install it. Runtime projection and
fresh-session discovery belong to a later, separately authorized Goal.
