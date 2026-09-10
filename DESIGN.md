# K4 Work Cycle Agent Extension Design

This document fixes the implementation boundary for [`WORKFLOW.md`](./WORKFLOW.md).
`WORKFLOW.md` is the semantic authority. This document may constrain how the
Extension realizes that authority; it may not add or redefine a stage.

## 1. Published unit

The Resource publishes one Agent Extension with:

1. one semantic authority, `WORKFLOW.md`;
2. five peer Agent Skills: Observe, Goal, Plan, Run, and Finish;
3. one stage-neutral deterministic Tool;
4. five Skill-local CUE contracts;
5. one generated Manifest;
6. one isolated conformance suite.

The five Skills realize four stable storage strategies. Observe and Finish
share the Account strategy at opposite temporal boundaries; Goal owns a flat
mandate, Plan owns an operation DAG, and Run owns an append-only journal.

The Skills are peers. Consumption order does not create ownership or an actor
hierarchy. The Extension does not create a daemon, task manager, permanent
role, installation provider, or sixth stage.

## 2. Semantic and mechanical ownership

Each Skill contains only the semantic guidance needed to form its temporary
candidate. Its CUE contract owns closed fields, enums, cross-field relations,
legal predecessor data, derived semantic fields, and refusal rules.

The shared Tool has no stage vocabulary. Its surface remains:

- `materialize`: validate and create one immutable document at an absent path;
- `append`: validate and atomically append one event to a chained JSONL ledger;
- `project`: validate a complete ledger and create an absent derived view;
- `validate`: revalidate a document or ledger without changing it.

The Tool owns canonical JSON, content and file digests, generated time, event
sequence and predecessor digests, exclusive creation, append locking, flush,
and failure-before-write. CUE owns the meaning of accepted data.

## 3. Five contracts

The contracts intentionally differ.

- Observe accepts a null predecessor or one exact Observe/Finish Account. An
  iteration keeps subject and boundary fixed, accounts for every prior item,
  and emits one new opening Account plus its observation report.
- Goal accepts one exact current Observe Account and materializes immutable
  acceptance points, controls, budget, resources, authority and execution
  envelope as a flat mandate with no operation order.
- Plan accepts one exact frozen Goal and materializes an immutable operation
  DAG with assignment, dependencies, concurrency guards and complete Tool,
  path, permission, effect, and recovery boundaries.
- Run accepts one exact Goal, Plan, existing ledger, and candidate operation or
  halt event. It validates eligibility and appends journal facts only.
- Finish accepts the exact pre-Goal Account, Goal, Plan, and halted Run. It
  reconciles the journal, evaluates acceptance and controls, and materializes a
  new closing Account plus its stage report in the closure fields.

Every binding includes schema, raw-file digest, and semantic content digest. A
binding proves the consumed bytes, not their truth or transferred authority.

## 4. Common Account contract

Observe and Finish each carry a self-contained CUE contract so either Skill can
be copied and used through the published Extension interface. Their Account
core definitions must remain mechanically equivalent. Conformance compares the
generated core fields and exercises Finish-to-Observe continuation.

Their report surfaces are deliberately different without becoming another
storage strategy. Observe's report indexes current status, gaps and possible
Goal inputs from the opening Account. Finish's closure records the bounded
stage judgment and exact journal reference used to form the closing Account.

`WORKFLOW.md` remains the single semantic authority for that common core. The
duplicated local encoding is a portability projection, not a second meaning.
Changing the Account core therefore requires changing both contracts and their
cross-contract conformance case in one source Candidate.

## 5. Stable and derived state

Observe, Goal, Plan, and Finish are immutable materialized documents. Run
events are immutable append-only journal facts. A Run projection is
reconstructible current state and never replaces the journal.

Temporary semantic inputs may be edited while being formed. Stable JSON and
JSONL bytes are generated only by the Tool after CUE accepts them. Stable
structured outputs are never hand-patched. A rejected input remains temporary
input plus its diagnostic.

Semantic content identity excludes generated observation time but includes
exact predecessor bindings. File identity includes complete canonical bytes.

## 6. Public interface and diagnostics

Every normal-use entrypoint must implement conventional `--help` output that
names its input, output, bindings, event kinds where applicable, and semantic
field vocabulary. Decisive predecessor constraints belong in that help: in
particular, Observe iteration requires unchanged subject and boundary.

A normal refusal must identify the public field or relation the caller can
correct. Raw CUE locations may supplement that message but cannot be the only
diagnostic. Callers use Skill text, reference, and `--help`; they do not need to
read CUE or Tool source during ordinary use.

## 7. Dependency and portability

The only fixed executable dependency is CUE `v0.17.1`. Each Skill contains a
standard `SKILL.md`, `assets/`, `references/`, and thin `scripts/` entrypoints.
Entrypoints resolve the shared Tool from the installed Extension projection and
never reach back into this source repository or another workspace.

The generated Manifest lists `WORKFLOW.md`, five Skills, the Tool, the CUE
version, and every published file identity. Source is authoritative. A provider
may later install ordinary copies and record their source identities, but
source publication and installation are separate operations and separate
Goals.

## 8. Conformance boundary

The suite preserves applicable established meanings: absent-output refusal,
valid selection, complete Goal and control coverage, safe DAG dependencies,
guarded concurrency, append ordering, invariant checks, execution completeness,
and existing-parent requirements. It also proves the five-stage lifecycle,
early/non-pass closure, Finish-to-Observe continuation, same-boundary Observe
iteration, and actionable subject/boundary-drift refusal.

The suite uses isolated temporary directories and adds no runtime artifact to
the Resource. Passing proves only declared mechanical contracts. It cannot
prove evidence truth, semantic sufficiency, authorization, or route wisdom.

Every contract preserves evidence for its own claims and successor boundary.
The resulting trace is an audit trail for a separately authorized independent
auditor. Internal dependency checks and Finish reconciliation remain internal
control; neither is relabeled as independent audit.

## 9. Projection boundary

This source release does not install itself. A later provider operation may
project the five Skill directories, shared Tool, and semantic authority into a
runtime and may update minimal routing instructions. Runtime discovery and a
fresh-session call are installation evidence. Reading this source tree is not.
