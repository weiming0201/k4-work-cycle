# K4 Work Cycle Agent Extension Design

[`WORKFLOW.md`](./WORKFLOW.md) is the semantic authority. This document fixes
how the published Agent Extension realizes it without redefining the stages.

## 1. Published unit

The Resource publishes:

1. one semantic authority, `WORKFLOW.md`;
2. five peer Agent Skills: Observe, Goal, Plan, Run, and Finish;
3. one stage-neutral deterministic Tool;
4. one Skill-local CUE contract per Skill;
5. one generated Manifest;
6. explicit adjacent-version migration Tools and frozen target contracts;
7. one isolated conformance suite.

The Skills are peers. Consumption order creates neither actor hierarchy nor
ownership. This release adds no daemon, task manager, provider, permanent role,
or sixth stage.

## 2. Separation of responsibilities

`SKILL.md` contains only the semantic guidance that changes how an Agent forms
the stage candidate. Detailed field vocabulary is disclosed by conventional
script `--help`; maintained protocol explanation lives under `references/`.
Ordinary use does not require loading CUE or Tool source.

Each local CUE contract owns closed fields, enums, cross-field relations,
predecessor compatibility, generated semantic projections, and refusal rules.
The shared Tool has no stage vocabulary. It provides only:

- `materialize`: create one immutable document at an absent path;
- `append`: atomically append one event to a chained JSONL ledger;
- `project`: create an absent view from a validated ledger;
- `validate`: revalidate an existing document or ledger without mutation.

The Tool owns canonical JSON, generated time, content and file digests, event
sequence and predecessor digest, exclusive creation, append locking, flushing,
and failure-before-write. CUE owns the meaning of accepted data. Each
version-specific migration Tool consumes one exact source chain and an explicit
policy for fields that cannot be inferred. The `0.4.1` migration uses frozen
`0.5.0` CUE contracts, so later releases cannot silently alter its target. The
`0.5.0` migration uses the frozen `0.8.0` target contracts to build a `0.6.0`
chain; later public schemas cannot silently alter that historical target.

## 3. Five unequal contracts

- Observe accepts a null predecessor or one exact Observe/Finish Account. It
  accepts only bootstrap semantics or an iteration delta, preserves Account
  continuity, and generates the complete Account, lens index, gap/conflict/
  unknown indexes, completeness surface, and opening report.
- Goal accepts one exact Observe Account and freezes one selected flat mandate,
  including its decision basis, change surface, seven-part boundary-feasibility
  review, selection rationale, exact execution envelope, and sourceable judge
  identities. Its source inventory and canonical empty collections are derived.
- Plan accepts one exact frozen Goal and freezes one selected forward binary
  operation DAG, including its selection rationale, topology projection, and
  Plan-level abort response.
  Roots, phases, join dependencies, identities, coverage, and topology are
  graph projections rather than caller-maintained fields. Every real operation
  owns structured preconditions, one complete local pass/fail judgment contract,
  and explicit failure handling.
  Every operational permission, position, resource, tool, and maximum effect
  is mechanically contained by the Goal envelope.
- Run accepts one exact Goal, Plan, existing ledger, and candidate event. It
  derives eligibility and the Plan-local judgment contract, validates graph
  activation, and appends only operation, patch,
  abort-confirmation, or halt facts. Fixed patch fields and ledger-determined
  terminal fields are generated before append; an actual patch Finding is not
  generated and remains required semantic input.
- Finish accepts the exact opening Account, Goal, Plan, and halted Run ledger.
  Its semantic input is a closing Account delta plus actual judgments, closure
  actions, attribution, residual effects and disposition. The Tool derives its
  Run projection, complete next Account, separate Account/closure source sets,
  settlement report, exact judges and comparison contracts frozen by Goal, and
  the uniquely empty terminal-result collection. Raw delta identity and route relations are
  preflighted before any lossy dictionary or set projection.

Every binding includes the referenced schema, raw-file digest, and semantic
content digest. It proves the exact consumed bytes, not their truth or a
transfer of authority.

## 4. Common Account

Observe and Finish encode the same Account fields:

- revision, subject, boundary, cutoff, and complete source references;
- declared observation lenses and generated lens-to-item index;
- current evidence delta;
- complete current items with continuity, epistemic kind, state, claim,
  evidence, and route;
- explicit retirement of predecessor items.

Observe and Finish carry self-contained copies of this contract so their Skill
directories remain portable inside the Extension. The copies are projections
of one meaning, not separate authorities. A change to the Account requires both
contracts and the Finish-to-Observe conformance case to change together.

Observe adds only the opening status and Goal-candidate index. Finish adds only
the closing settlement report. Neither report is a second ledger.

## 5. Graph and journal

Plan input uses operation indices so a caller does not hand-generate content
identities. The Tool derives normal roots, phases and join barriers, generates
operation ids, and replaces index references with exact ids. Dependencies and
result edges must point forward and cannot cross phases. Plan owns one
`on_abort` response: `preserve-only`, or a separate abort-route entry. It
derives start, fork, join, and end positions from the selected graph.

Run treats that graph as scheduling authority. Only local `pass` and `fail`
choose an operation edge. Findings and unknowns are event annotations. At most one
emergency patch may precede an activated normal operation response, and its
verification scope is fixed to mainline resumption. Abort requires one sourced
external cancellation or recoverable runtime fact; Run then follows only the
Plan's frozen response and cannot patch that response. A halt is exactly
`plan-complete` or `abort`; an incomplete ledger is merely open. The projection
retains every Plan operation as `pass`, `fail`, or `not-run` and reports only
`open`, `plan-complete`, or `abort` topology while the journal
remains the only process history. Patch tools, permissions, read/write
positions, resources, and maximum effects remain inside the Goal envelope
rather than widening it at runtime.

## 6. Stable and temporary state

Temporary semantic inputs may be edited during formation. Observe
iteration and Finish settlement inputs contain changed, added, and retired
Account semantics; retained items and all aggregate Account fields are
mechanically derived. Goal sources and canonical empty collections, Plan graph
projections, and Run's fixed or ledger-determined fields are also generated.
Observe, Goal, Plan, Finish, and Run projections are immutable materialized documents. Derived
fields are rejected at the public semantic boundary rather than accepted as
caller-maintained compatibility copies. A Run
projection is valid only relative to its exact source ledger. Run events are
immutable append-only facts. Stable structured outputs are created only by the
Tool and are never hand-patched.

Semantic content identity excludes generated time but includes exact bindings.
File identity includes all canonical bytes. A rejected input remains temporary
input plus its diagnostic; it never becomes a partial stable result.

Migration does not preserve a content digest by assertion. It preserves the
source artifacts, records their file digests, obtains explicit values for new
semantic obligations, and generates new artifacts and a new Run hash chain.

## 7. Diagnostics and lazy CUE

Every public script implements conventional `--help` and states its current
inputs, outputs, bindings, and public semantic fields. Refusals identify the
field or relation the caller can correct.

CUE is lazy. A check has public force only when the expression used by
`materialize`, `append`, `project`, or `validate` directly includes it. Merely
declaring an unused sibling constraint is not enforcement. Generation and
validation therefore expose equivalent continuity and transition checks.

## 8. Dependency and portability

The fixed executable dependency is CUE `v0.17.1`. Entrypoints locate the shared
Tool from the installed Extension projection and do not reach into another
Workspace. The generated Manifest lists the semantic entry, five Skills,
contracts, entrypoints, Tool, dependency version, and every published file
identity.

Source publication and runtime installation are separate operations. A future
provider may project ordinary copies into Codex, Claude Code, or another
runtime, but provider behavior is outside this release.

## 9. Conformance boundary

The isolated suite exercises one complete cycle, including:

- multi-lens Observe bootstrap, delta-only Finish-to-Observe continuity,
  automatic retention and source aggregation, and aggregate field diagnostics;
- a frozen Goal that retains an unknown annotation;
- rejection of a frozen Goal without acceptance and of an unavailable judge;
- forward binary Plan routing with fork and join projections, separated normal
  and abort phases, and a Plan-owned abort response;
- six-family Goal-envelope containment for Plan operations and emergency patches;
- Run activation, one emergency patch, patch refusal on repetition, binary
  results, explicit abort confirmation, two-state halt, and projection;
- Finish settlement in which a failed operation is recovered by the frozen
  route and the Goal still passes;
- Finish projection of the Goal judge/comparison contract and rejection of a
  caller-supplied replacement scale;
- legal zero-control and zero-patch settlement;
- full adjacent `0.4.1` to `0.5.0` and `0.5.0` to `0.6.0` chain migrations with
  explicit digest transitions;
- refusal of a Plan back edge and an unactivated Run operation.

Passing proves only these mechanical contracts. It does not prove evidence
truth, semantic sufficiency, route wisdom, authorization, adoption, or
publication. The trace supports a separately authorized audit; it does not
perform that audit.
