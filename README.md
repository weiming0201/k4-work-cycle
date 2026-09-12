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
[`MIGRATION.md`](./MIGRATION.md) only when upgrading an older chain.

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
tools/migrate-0.5.0-to-0.6.0
tools/contracts/0.5.0/
tools/contracts/0.8.0/
skills/
  k4-observe/{SKILL.md,assets/,references/,scripts/}
  k4-goal/{SKILL.md,assets/,references/,scripts/}
  k4-plan/{SKILL.md,assets/,references/,scripts/}
  k4-run/{SKILL.md,assets/,references/,scripts/}
  k4-finish/{SKILL.md,assets/,references/,scripts/}
tests/conformance.py
tests/input_minimality_oracle.py
tests/fixtures/0.4.1/
tests/fixtures/0.5.0/
```

The only fixed executable dependency is CUE `v0.17.1`. The shared Tool is
stage-neutral; every Skill supplies its own CUE contract.

## Mechanical interface

Skill-local scripts are the public entrypoints. Observe, Goal, Plan, and Finish
materialize immutable documents. Run appends one event, projects its ledger,
and validates either the ledger or its derived projection. Every stable JSON or
JSONL output is Tool-generated; semantic input remains a temporary work product.
The Observe-iteration and Finish-settlement interfaces accept changed,
added, and retired Account semantics without requiring the complete Account.
Goal sources, Plan graph projections, Run eligibility and Plan-local judgment
contracts, Finish judge/comparison contracts, source closures, and both complete
Accounts are Tool-derived rather than caller-maintained.

Finish checks update identities, update-retirement collisions, and item routing
before projecting the closing Account; a closing item cannot retain
`goal-candidate`. It generates omitted terminal-control results only when the
bound Goal has none. Run generates fixed patch metadata, but an emergency patch
must still supply at least one actual Finding.

Release `0.9.0` changes the public stable chain to Observe v3, Goal v7, Plan v8,
Run event/projection v7, and Finish v5. It adds Observe completeness/indexes,
Goal decision/feasibility surfaces, per-operation Plan audit and recovery,
Run-local judgment without whole-Goal conclusion, and Finish closure work,
attribution, residual effects and split source closures. Caller-maintained
derived fields are rejected. The prior contracts remain frozen under
`tools/contracts/0.8.0/`; existing chains remain valid but are not silently
reinterpreted as v0.9.0 chains.

Release `0.8.0` minimized temporary caller input while preserving its stable
output schemas and stage meanings.

Release `0.7.0` replaces Observe's full-Account temporary input with a
delta-only interface. The stable Observe schema remains v2; existing Account
consumers do not migrate. The Tool now derives retained items, continuity,
source references, lenses, indexes, ids, and envelope metadata.

Release `0.6.0` gave Run exactly two terminal states, `plan-complete` and
`abort`, while keeping operation `pass`/`fail` independent. Plan owns one
explicit `on_abort` response: preserve evidence only or enter a separate finite
abort route. Run may record abort only from an explicit external or recoverable
runtime fact; it cannot choose or invent the response.

Existing chains are never edited in place. Use the exact versioned migration
Tool documented in [`MIGRATION.md`](./MIGRATION.md). Frozen `0.5.0` contracts
remain in `tools/contracts/0.5.0/`, preventing the older migration Tool from
silently targeting current schemas.

Run the source conformance suite from the Resource root:

```text
python3 tests/conformance.py
```

Tests use isolated temporary directories and include frozen `0.4.1` and
`0.5.0` migration fixtures. Mechanical validation proves only
declared structure, bindings, write semantics, and transitions. It does not
prove evidence truth, Goal or Plan sufficiency, or external authorization.

Publishing this Resource does not install it. Runtime projection and
fresh-session discovery belong to a later, separately authorized Goal.
