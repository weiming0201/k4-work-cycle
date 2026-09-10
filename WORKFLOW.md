# K4 Work Cycle

K4 Work Cycle turns one evidenced situation into one bounded attempt, records
what actually happens, and settles the result back into the situation account.

```text
Observe -> Goal -> Plan -> Run -> Finish
   ^                                  |
   `------ a later task may bind -----'
```

The five names are responsibilities, not actors and not five copies of one
generic form. They use four storage strategies:

- Observe and Finish maintain the same full Account at different temporal
  boundaries;
- Goal freezes one flat acceptance and execution mandate;
- Plan freezes one finite operation DAG;
- Run appends one linear event ledger.

A later Observe may consume a Finish Account. That begins another task; it does
not make the current Run self-revising.

## 1. Observe: open the general ledger

Observe identifies one bounded subject, its authoritative Assets and evidence,
and the observation lenses needed to understand it. It produces one full
Account. The Account is a source-bound structured observation surface, not a
copy that replaces the source authority.

Each lens is a different view of the same subject—for example structure,
behavior, dependency, provenance, or another useful perspective. Every Account
item belongs to one declared lens and distinguishes its epistemic kind, state,
minimum supported statement, evidence, continuity, and route. The generated
lens index makes each view directly addressable without creating another
ledger.

Observe either bootstraps a new Account or iterates one exact Observe/Finish
Account:

```text
Account[0]   = observe(null, Evidence[0])
Account[n+1] = observe(Account[n], DeltaEvidence[n+1])
```

Iteration keeps subject and boundary fixed and accounts for every predecessor
item exactly once as retained, changed, or retired; new items are added.
Observe exposes current gaps, conflicts, unknowns, and Goal candidates, but it
does not select a Goal, define acceptance, choose operations, modify the
observed subject, or close an attempt.

## 2. Goal: freeze the selected mandate

Goal binds one exact Observe Account and selects only explicit Goal candidates
from it. It freezes the baseline, target, evidence cutoff, scope, acceptance
points, bounded judges, available tools, authority, resources, budget, maximum
effects, and execution controls for one attempt. The execution envelope names
the exact available tools, permissions, readable and writable positions,
resources, and maximum effects; later stages may narrow but not enlarge it.

When useful, Goal formation may compare two or three materially different
candidates. The stable result retains only the selected Goal and a concise
selection rationale. Rejected alternatives are generation process, not stable
parallel mandates.

Acceptance points define observable terminal differences and how they will be
judged. Every judge has a sourceable identity as well as a bounded kind and
claim limit. Controls define execution variables, allowed domains, forbidden drift,
required traces, methods, and check timing. Neither defines an operation.
Unknowns remain annotations; only a blocker prevents freezing. A frozen Goal is
immutable and single-use. Goal does not choose a route, form a graph, execute
work, or admit post-cutoff evidence as though it were part of the prediction.

## 3. Plan: freeze the permitted evolution

Plan binds one exact frozen Goal and selects one finite operation DAG. When
useful, formation may compare two or three materially different DAGs; the
stable result retains only the selected Plan and its concise selection
rationale.

Each real operation declares:

- the Goal points and controls it serves;
- its tool, responsible executor, readable and writable positions;
- permissions, resources, and maximum side effects;
- pre-checks, post-checks, idempotency, retry ceiling, and recovery;
- exactly two result edges, `pass` and `fail`.

Both result edges may point to the same successor. An edge with no successor
reaches end; multiple successors form a fork. A join waits for all declared
predecessor operations, and each such predecessor routes both outcomes to that
join. Every dependency and result edge points forward in topological order, so
the materialized graph is acyclic. Start, fork, join, and end are structural
positions, not additional operation results.

Plan turns the Goal's flat constraints into task-specific scheduling authority.
Every operation's tool, permissions, read/write positions, resources, and
maximum effects must be contained by the Goal execution envelope. An
independent judge cannot also execute the operation serving the point or
control it judges. Plan does not change the Goal, perform work, or record
actual results. Findings and unknowns do not create new graph branches.

## 4. Run: append the actual journal

Run binds one exact Goal and Plan. It starts from the Plan entry, executes each
activated operation once, records `pass` or `fail`, and follows only the frozen
edge for that result. Forks activate every successor. Joins become eligible
only after all declared predecessors have responses. Unselected operations
remain truthfully `not-run` in the derived projection.

Run may search, inspect, and choose implementation details needed by the active
operation within the frozen authority. A Finding or unknown may accompany
either binary result and has no routing authority.

If a significant Plan omission prevents the active operation, Run may make at
most one emergency patch attempt for that operation. The patch records its
reason, script, tools, exact positions, maximum and actual effects, trace,
application result, Findings, and unknowns. Its tools, permissions, positions,
resources, and maximum effects remain inside the Goal envelope. It is checked
only far enough to resume the original operation; it receives no separate
systematic test. The original operation is then retried and still produces
`pass` or `fail`.

Run halts as:

- `plan-complete` when every activated route has reached an end;
- `blocked` when the frozen route cannot continue within authority after the
  permitted patch;
- `cancelled` when the attempt is externally cancelled.

Every event is appended once and never rewritten. The Run projection is
reconstructible current state, not another history. Run does not replan, judge
the final Goal, adopt output, publish, or choose the next Goal.

## 5. Finish: settle the ledger

Finish binds the exact opening Account, Goal, Plan, and halted Run ledger. The
Tool derives its current projection from those exact bytes. Finish may follow recorded evidence
references when settlement needs detail, but it does not repair the attempt or
invent missing events.

Finish performs two inseparable projections of one settlement:

1. it updates the same full Account opened by Observe, preserving subject,
   boundary, and lenses while accounting for every predecessor item;
2. it produces a completion report containing Goal judgments, actual and
   not-run operations, operation pass/fail counts, Findings, unknowns,
   emergency patches, halt, result placement, and incomplete work.

Every Goal acceptance point and terminal control receives a binary judgment
from the exact judge identity frozen by Goal. Unknowns remain attached
annotations. An attempt passes only when Run reaches
`plan-complete` and all acceptance, terminal-control, and invariant-control
judgments pass. A failed operation may therefore be recovered by its frozen
fail route; operation failure alone does not decide the Goal.

Finish does not modify Goal or Plan, append Run events, repair, adopt, publish,
or select a future Goal. The next Observe decides how the settled Account
changes the opportunity inventory.

## 6. Stable boundaries

Open-ended generation forms temporary semantic candidates. The deterministic
Tool validates each Skill's CUE contract, binds exact predecessors, generates
identities and ordering, writes stable bytes, appends journal events, and
refuses invalid transitions. Stable JSON and JSONL are never hand-authored or
patched.

Mechanical success proves only the declared structure, binding, and transition.
It does not prove source truth, Goal wisdom, Plan sufficiency, external
authorization, semantic correctness, adoption, or publication. The complete
trace is evidence available to a separately authorized audit; internal checks
and Finish settlement do not become independent audit by possessing it.
