# K4 Work Cycle

K4 Work Cycle narrows an open situation into one bounded attempt and then
returns the actual outcome to the next round of alignment. It is composed from
four different document protocols, not four instances of one result format.

```text
Align[n] -> Goal[n] -> Plan[n] -> Run[n] -> Align[n+1]
```

The arrows declare consumption order. They do not make the four protocols
symmetrical and do not require four actors, four processes, or one permanent
runtime.

## Align: an iterated full account

Align states the evidenced situation currently visible inside one observation
boundary. It classifies what is aligned, open, conflicting, or unknown and
exposes possible inputs to a later Goal.

An initial Align has no predecessor. It starts from a bounded subject and a
declared evidence set:

```text
Align[0] = align(null, Evidence[0])
```

A later Align consumes one exact prior Align plus an evidence delta and emits a
new full account:

```text
Align[n+1] = align(Align[n], DeltaEvidence[n+1])
```

The new document identifies retained, changed, added, and retired statements.
It is not an appended diary and does not modify its predecessor. A failed,
paused, cancelled, or completed Run may all provide evidence to a later Align;
Align reports the actual settled situation rather than turning it into success.

Align may propose a next direction. It does not freeze a desired terminal
state, acceptance test, action route, or permission.

## Goal: a one-use set of audit points

Goal binds one exact Align selection and freezes one attempt's current
baseline, predicted terminal state, and method of judging that terminal state.
Its acceptance points say what must be observable, under which conditions,
what would falsify the prediction, how evidence is sampled, and who may make
which bounded judgment. Its execution envelope freezes the tools, authority,
resources, budget, maximum effects, stop conditions, and controls available to
the attempt.

A Goal is immutable and single-use as a contract. A semantic change produces a
new Goal; evidence gathered after its cutoff cannot be used to rewrite its
prediction. Goal defines what counts as reaching the terminal state. It does
not define the transition that reaches it.

## Plan: a one-use transition DAG

Plan binds one exact Goal and freezes one selected transition from the Goal's
baseline to its predicted terminal state. Its nodes declare operations; its
edges declare necessary precedence. Every operation fixes its tool or action,
responsible executor, inputs, outputs, readable and writable positions,
permissions, resources, maximum effects, checks, retry ceiling, and recovery
position. Concurrency exists only where the graph and explicit guards permit
it.

A Plan is immutable and single-use as an execution contract. A changed route,
operation, dependency, tool, path boundary, or recovery rule requires a new
Plan. Plan constrains how state may evolve. It does not claim that any
operation actually happened.

## Run: a monotonic event ledger

Run binds one exact Goal and its exact Plan. It records what actually happens
as an append-only sequence of events. Each event has a mechanical sequence,
predecessor identity, time, Plan position, evidence, effects, and outcome. An
event never rewrites an earlier event, and a later success never removes an
earlier failure.

The current Run view is a mechanical projection of the Goal, Plan, and complete
event sequence. It can be rebuilt and therefore is not an alternative history.
The projection separates operation outcomes, Goal acceptance judgments,
control judgments, budget and effect evidence, and the actual stop state.

Run follows the Plan. It does not silently replan, widen authority, adopt an
output, or choose the next Goal. When the Plan can no longer govern the next
action, Run stops at a recoverable position and returns the resulting evidence
to Align. Potential unresolved issues discovered during an operation are part
of its Run record; they are preserved as evidence but cannot trigger any
unplanned investigation, repair, or other action in that Run.

## Shared boundary

The four protocols share only their cycle, exact predecessor identity, evidence
discipline, and deterministic write boundary. Their document shapes, update
semantics, and completion conditions remain different:

| Protocol | Stable shape | Change rule |
| --- | --- | --- |
| Align | full current account plus explicit delta impact | create a new iteration |
| Goal | audit-point contract | create a new contract |
| Plan | operation DAG | create a new graph |
| Run | event ledger plus derived view | append an event; rebuild the view |

Open-ended generation supplies semantic candidates. Deterministic mechanisms
validate contracts, bind exact predecessors, generate identities and ordering,
write stable bytes, and refuse invalid state transitions. Mechanical success
does not prove that evidence is true, a Goal is wise, or a Plan is sufficient.

Completion of a Run does not itself adopt, publish, or make its outputs
authoritative. Those effects require their own owner, authority, and operation.
