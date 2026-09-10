# K4 Work Cycle

K4 Work Cycle narrows one evidenced situation into one bounded attempt, records
what actually happened, closes that attempt truthfully, and returns the resulting
situation for renewed observation.

```text
Observe* -> Goal -> Plan -> Run -> Finish -> Observe*
```

The arrows are exact consumption relations. The five stages are responsibilities,
not actors or five instances of one generic form. They use four storage
strategies: Observe and Finish both produce a full Account; Goal produces a
flat mandate; Plan produces an operation DAG; Run produces an append-only
journal. Alignment is the relation each boundary must preserve, not a sixth
stage.

## Observe: open the general ledger

Observe creates a sourced full Account of one subject inside one observation
boundary. A bootstrap Account begins without a predecessor. A later Observe
binds one exact prior Account produced by Observe or Finish, admits an evidence
delta, and creates a new full Account:

```text
Account[0]   = observe(null, Evidence[0])
Account[n+1] = observe(Account[n], DeltaEvidence[n+1])
```

Every new Account states its subject, included and excluded boundary, evidence
cutoff, sources, delta, and current items. Each current item is retained,
changed, or added; every absent predecessor is explicitly retired. Items keep
fact, source statement, inference, preference, conflict, gap, and unknown
distinguishable. Its observation report exposes the current status and indexes
Goal candidates from those items. The Account is the opening general ledger;
the report is its gap and opportunity view. A Goal candidate is only an exposed
possibility, not a selected task.

Observe is repeatable and side-effect-free with respect to the observed object.
It does not define acceptance, choose operations, execute repair, or judge a
finished attempt. Iteration preserves subject and observation boundary. A new
subject or boundary starts a new bootstrap Account instead of disguising a
scope change as evidence delta.

## Goal: freeze the flat mandate

Goal binds one exact current Observe Account and selects its explicit Goal
candidates. It freezes one attempt's baseline, predicted terminal state,
evidence cutoff, acceptance points, execution controls, available tools,
authority, resources, budget, maximum effects, stop conditions, and incomplete
deliverable.

These clauses are a flat responsibility set. Goal does not order them into
work. Acceptance states how the result will be assessed; budget and resources
bound what may be consumed; authority and controls bound conduct; stop
conditions and the incomplete deliverable limit loss when the attempt cannot
complete.

Acceptance points define observable terminal differences and how they will be
judged. Controls define variables that must remain inside declared bounds while
the attempt runs. Goal determines what would count as an acceptable attempt;
it contains no operation or route.

A frozen Goal is immutable and single-use. If formation remains interrupted,
unknown, or blocked, no Run failure has occurred: the attempt has not started.
A semantic change requires a new Goal bound to the still-current Account, or a
new Observe first when reality or the evidence cutoff has changed.

## Plan: organize the permitted work

Plan binds one exact frozen Goal and defines one operation DAG from its baseline
toward its predicted terminal state. Every node fixes its dependencies, Goal
points and controls served, tool, executor, readable and writable positions,
permissions, resources, maximum effects, checks, retry ceiling, and recovery.
The graph turns the flat mandate into assigned work: who or what performs each
operation, which results are prerequisites, and which independent operations
may run in parallel. Concurrency exists only where the graph and explicit
guards permit it.

Plan reduces later execution to governed choices. It neither changes Goal
criteria nor records actual work. A route, operation, dependency, tool, path,
permission, effect, or recovery change requires a new Plan. If an executable
Plan cannot be formed, no Run failure has occurred.

## Run: append the actual journal

Run binds one exact Goal and its exact executable Plan. It attempts only an
eligible Plan operation and appends the actual result, evidence, trace,
invariant-control observations, and deferred issues. Earlier events are never
rewritten. A current projection is mechanically reconstructible from the
journal and is not a second history or a general ledger.

Run may halt after any operation. Its final event records only the actual halt:
where execution stopped, what triggered the stop, observed budget and effects,
and the available resume position. Run does not judge Goal acceptance or
terminal controls, decide whether the overall attempt completed, repair,
replan, adopt output, publish by implication, or choose the next Goal.

An issue outside the current operation is recorded for later reconciliation and
cannot trigger unplanned work. When Plan, authority, resources, or checks no
longer govern the next action, Run halts rather than expanding the attempt.

## Finish: close the general ledger

Finish binds the exact pre-Goal Account, Goal, Plan, and halted Run. From those
frozen inputs it judges every Goal acceptance point and terminal control,
determines the truthful terminal state, identifies actual result placement,
and preserves an incomplete deliverable and resume position whenever work did
not complete.

Finish emits a new full Account with the same common Account core as Observe.
Its evidence delta is the bounded attempt and its verified outcome: Run's
journal is reconciled with the opening Account, Goal, and Plan before entering
the closing general ledger. Finish adds a stage report through its closure:
exact attempt bindings, bounded acceptance and control judgments, terminal
state, result disposition, incomplete package, resume information, and exact
Run reference. It does not repair the attempt, perform adoption or publication,
or select the next Goal. Such effects exist only when they were authorized Plan
operations.

Finish is internal reconciliation and closing judgment. It may preserve or
consume independent audit evidence, but its own report is not an independent
external audit merely because the full trace is available.

The Finish Account is a legal predecessor for the next Observe. That Observe
may add external changes that occurred before, during, or after the Run and may
then expose a later Goal candidate.

## Five responsibilities, four storage strategies

Observe and Finish share one content-addressed Account core:

- subject and observation boundary;
- evidence cutoff and complete source references;
- evidence delta;
- the full current item set with retained, changed, and added impact;
- explicitly retired predecessor items;
- exact predecessor identity when one exists.

Finish alone adds the closing stage report. Observe alone adds the opening gap
and opportunity report and may expose Goal candidates. Their common core makes
the terminal situation directly continuable without pretending that opening
inventory and closing reconciliation are the same operation.

| Responsibility | Storage strategy | Stage-specific role | Change rule |
| --- | --- | --- | --- |
| Observe | full Account | opening inventory plus gap/opportunity report | create a new Account iteration |
| Goal | flat mandate | acceptance, budget, resources, authority, controls and stop-loss | create a new single-use contract |
| Plan | operation DAG | dependencies, assignment, permitted concurrency and recovery | create a new single-use graph |
| Run | journal plus derived projection | actual operation and halt facts | append one event |
| Finish | full Account | closing reconciliation plus stage report | create once from one halted Run |

Each responsibility retains evidence for its own claims and the next boundary.
Together the Account, mandate, DAG, journal, closure, exact bindings, and stable
object evidence form an audit trail. They are evidence available to an
independent external audit; their existence does not perform that audit.

Open-ended generation supplies semantic candidates. Deterministic mechanisms
validate contracts, bind exact predecessors, generate identities and ordering,
write stable bytes, and refuse invalid transitions. Mechanical success proves
only those declared relations. It does not prove evidence truth, Goal wisdom,
Plan sufficiency, external authorization, or result adoption.
