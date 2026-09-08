# Align, Goal, Plan, Run

> This Resource is derived from the current work-contract responsibilities in
> `resource-033@bb64afe05f1f7d447ff17ace70113a8671d82566`. It is an external
> Ability Resource, not part of Agent Frame and not an authority projection of
> any particular Provider.

## 1. One cycle, four stable results

The cycle is `Align -> Goal -> Plan -> Run -> Align`.

- Align owns the evidenced description and routing of current differences.
- Goal owns the result acceptance set, execution envelope, and control
  contracts for one increment.
- Plan owns one selected route and the operation dependency graph used to
  attempt that Goal.
- Run owns the actual operation records and the separate judgments against the
  Goal's acceptance and control contracts.

These are four Skills, not four Agents, actor roles, mandatory project
directories, or a Workflow that must always run. A consumer may compose them
into a Workflow; this Resource does not create that runtime.

## 2. Binding direction

Align may bind one Run when reconciling an attempt, or no Run for cold-start
observation. Goal binds one Align and selects only its `goal-candidate` item
IDs. Plan binds one frozen Goal. Run binds the same Goal and one executable
Plan already bound to it.

Each binding contains the predecessor's raw-file SHA-256 and semantic-content
SHA-256. The immediate consumer verifies the supplied bytes. Binding preserves
identity; it does not copy authority or predecessor content.

## 3. Semantic input and mechanical generation

The AI authors temporary semantic input: statements, classifications,
references, acceptance and control contracts, operation descriptions, and
actual result claims. That input is process material, not the stable result.

Rust alone generates the stable envelope and closed structure, schema version,
timestamp, IDs, predecessor bindings, coverage indexes, control timing,
aggregate status, digest, canonical serialization, and absent-path output.
Unknown or extra input fields are rejected. Stable JSON is never hand-patched.

Every Skill exposes one type-specific Rust executable with two operations:

| executable | Skill operation | external check |
| --- | --- | --- |
| `k4-align-result` | `generate` | `validate` |
| `k4-goal-result` | `generate` | `validate` |
| `k4-plan-result` | `generate` | `validate` |
| `k4-run-result` | `generate` | `validate` |

The Skill calls only its own `generate`. Tests, consumers, and auditors may
call `validate`. Generation uses the same validator before and after exclusive
creation of the output.

## 4. Align boundary

Align freezes one observation subject, boundary, cutoff, declared source set,
and sourced items classified as `aligned`, `gap`, `conflict`, or `unknown`.
Each item routes to `none`, `goal-candidate`, `retain`, or an identified
external destination.

Align does not define a desired result, acceptance criterion, control method,
or operation. Source coverage proves only that every declared source was used;
it cannot prove that the declared source set exhausts reality.

## 5. Goal boundary

Goal freezes three distinct things:

1. acceptance points state which observable results must pass and how each is
   falsified and judged;
2. control contracts state which execution variable must remain within which
   domain, what drift is forbidden, how it is traced and checked, and whether
   the check is invariant or terminal;
3. the execution envelope states authority, resources, budget, maximum side
   effects, stop conditions, and the incomplete deliverable.

Acceptance is about the result. Control is about keeping execution within its
declared domain. Neither is an operation or a route, and neither substitutes
for the other. A judge is `self`, `independent-agent`, `script`, or `human`
with an explicit claim limit. Goal does not plan or execute work.

## 6. Plan boundary

Plan is one flat operation DAG. Each operation declares its dependencies,
Action or Tool reference, responsible executor, inputs, outputs, permissions,
resources, maximum effects, checks, retry ceiling, and recovery. It also names
the Goal acceptance points it helps satisfy and the Goal controls it must obey.

Rust derives the reverse coverage index. An executable Plan must cover every
Goal acceptance point and control contract. Multiple operations may satisfy
one acceptance point; one operation may support multiple points; enabling
operations may satisfy none. This deliberately prevents a Goal point from
being mistaken for a Plan node.

Dependencies express necessary precedence. Missing dependency edges do not
grant concurrency. Parallel execution is allowed only through an explicit
group whose members have no dependency path and whose reason and guards are
stated. Plan stores the selected route, not discarded exploration or actual
execution.

## 7. Run boundary

Run attempts only the operations already named by the Plan. It records every
Plan operation, every Goal acceptance point, and every Goal control contract
exactly once. These records are separate because operation success, result
acceptance, and control compliance are different claims.

An operation cannot run after a non-pass dependency. An acceptance result
cannot pass until every mapped operation passes. An invariant control cannot
remain `not-run` after any operation governed by it has run; a terminal control
may remain pending until the terminal check. Rust copies the required control
timing from Goal rather than accepting it from semantic input.

Run does not replan, broaden authority, adopt output, or select the next Goal.
Its result may become input to a new Align. Version 1 deliberately excludes
automatic reuse of evidence from an older Run.

## 8. Mechanical and semantic limits

The kernel can prove exact fields, closed enums, nonempty requirements,
generated IDs, declared-source coverage, exact predecessor bytes, Goal-to-Plan
coverage, acyclic operation dependencies, guarded parallel structure, complete
Run coverage, dependency eligibility, mapped-operation prerequisites,
invariant-control timing, aggregate statuses, digests, and absent atomic output
creation.

It cannot prove that Align observed everything relevant, Goal contracts are
semantically sufficient, a Plan route is wise, external authority or evidence
is genuine, or an action happened merely because a reference was supplied.
Those remain bounded semantic judgments and external reality checks.
