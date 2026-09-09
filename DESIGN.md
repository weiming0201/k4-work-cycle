# K4 Work Cycle Agent Extension Design

This document fixes the implementation boundary for the semantics in
[`WORKFLOW.md`](./WORKFLOW.md). `WORKFLOW.md` is the outer semantic
authority; this document may explain how the current Extension realizes it but
may not change the four protocols.

## 1. Published unit

The Resource publishes one Agent Extension with six functional parts:

1. one outer `WORKFLOW.md`;
2. four peer Agent Skills, one for each document protocol;
3. one shared deterministic Tool;
4. four stage-local CUE contracts;
5. one generated Manifest;
6. one isolated conformance test preserving the established behavioral cases.

The four Skills are peers. None owns another Skill. Their predecessor bindings
come from the document cycle, not from a Skill hierarchy. The Extension does
not create a daemon, a permanent task manager, an actor role, or a fifth stage.

## 2. Semantic and mechanical ownership

Each Skill owns only the decisions needed to author its temporary semantic
candidate. Its local CUE contract owns that protocol's closed fields, enums,
cross-field conditions, legal predecessor data, derived semantic view, and
refusal rules.

The shared Tool is stage-neutral. It receives a CUE contract and data; it does
not contain Align, Goal, Plan, or Run field names or business enums. Its entire
mechanical surface is:

- `materialize`: validate and create one immutable document at an absent path;
- `append`: validate and atomically append one event to a chained JSONL ledger;
- `project`: validate a complete ledger and create one derived view at an
  absent path;
- `validate`: revalidate a document or ledger without changing it.

The Tool owns canonical JSON bytes, content digests, timestamps, event sequence
and predecessor digests, exclusive creation, append locking, flush, and
failure-before-write. CUE owns the meaning of the supplied data and resulting
document.

## 3. Four contracts

The contracts deliberately have different shapes.

- Align accepts either a null predecessor or one exact prior Align. With a
  predecessor it checks the declared evidence delta and the retained, changed,
  added, and retired impact against the emitted full account.
- Goal accepts one exact Align and materializes immutable audit points,
  execution boundaries, and control definitions. It never imports evidence
  after the frozen cutoff.
- Plan accepts one exact Goal and materializes an immutable operation DAG. It
  checks references, coverage, acyclicity, explicit path and Tool boundaries,
  and guarded concurrency.
- Run accepts one exact Goal, its exact Plan, the existing event ledger, and one
  candidate event. It checks event eligibility and emits the next event. A
  separate expression derives the complete current projection from the ledger.
  Potential unresolved issues remain recorded in their operation event and
  cannot trigger an unplanned action in that Run.

An exact predecessor binding includes its schema, raw-file digest, and semantic
content digest. A binding proves the bytes consumed; it neither copies the
predecessor's authority nor proves its claims.

## 4. Stable and derived state

Align, Goal, and Plan are immutable materialized documents. An update always
creates a new file. Run events are immutable appended facts. The Run projection
is derived and can be regenerated; it must never be treated as a second event
history.

Temporary semantic inputs are editable work products. Stable structured files
are generated only by the Tool after the relevant CUE expression accepts the
input. A stable file is never hand-patched. A rejected candidate remains
temporary input plus an error report.

Content identity excludes observation time but includes semantic content and
exact predecessor bindings. File identity includes the complete canonical
bytes. This separates reproducible meaning from the time a particular file was
materialized.

## 5. Dependency and portability

The fixed external dependency is CUE `v0.17.1`. Every Skill contains a
standard `SKILL.md`, its own `assets/`, `references/`, and thin
`scripts/` entrypoints. The entrypoints resolve the shared Tool from the
installed Extension projection and never reach back into the source repository
or a Rust workspace.

The source Manifest lists the outer document, the four Skills, the Tool, the
CUE version, and all published files. It is generated and validated rather than
hand-maintained as stable JSON. Provider installation creates ordinary file
copies and records their source identities; source remains authoritative.

## 6. Compatibility boundary

The replacement must preserve the established content restrictions even where
the storage shape changes. The conformance test therefore retains the
existing complete-cycle case and existing refusal classes: occupied output,
unknown Align selection, missing Goal coverage, unsafe parallel dependency,
cyclic Plan, corrupted coverage, dependency bypass, premature acceptance,
unchecked invariant control, incomplete execution coverage, and missing output
parent.

Passing these cases proves only the declared mechanical contracts. It cannot
prove evidence truth, semantic sufficiency, external authorization, or the
wisdom of the chosen route.

## 7. Codex projection

Codex consumption installs the four Skill directories as ordinary user-level
copies, installs the shared Tool and `WORKFLOW.md`, and adds only the minimum
global routing statement needed to require Align, Goal, and Plan before a
goal-scale Run. A fresh session must discover and call the installed Skills;
reading the source directory directly is not runtime confirmation.
