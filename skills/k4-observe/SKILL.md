---
name: k4-observe
description: Maintain one sourced opening Account through multiple declared observation lenses and expose current gaps and opportunities before Goal selection. Use at cold start or after a prior Finish; do not define acceptance, choose operations, repair the subject, or close an attempt.
---

# K4 Observe

Create the current opening Account for one bounded subject.

## Boundary

- Treat authoritative Assets and evidence as the observed sources. The Account
  is their derived, source-bound general ledger, not a replacement authority.
- Maintain one Account through multiple declared observation lenses. A lens is
  a useful view of the same subject, such as structure, behavior, dependencies,
  or another task-relevant perspective; it is not a second ledger.
- Bootstrap without a predecessor, or iterate one exact Account produced by
  Observe or Finish. Changed subject or boundary requires a new bootstrap.
- On iteration account for every prior item as retained, changed, or retired;
  mark new items added and bind changes to current evidence.
- Keep facts, source statements, inferences, preferences, conflicts, gaps, and
  unknowns distinguishable. A `goal-candidate` is only an opportunity.
- Do not select a Goal, define acceptance, choose operations, modify the
  observed subject, execute work, or close an attempt.

## Produce the Account

Choose the observation lenses needed to understand the bounded subject. Search,
inspect, compare, or derive views as the subject requires. For each current
item, state its lens, continuity relation, epistemic kind, current state,
minimum supported claim, evidence, and route.

The stable output contains the full Account, an index from every declared lens
to its items, the aggregate opening status, and the current Goal candidates.
It contains only the current result, not the discarded exploration used to
form it.

## Materialize

Run `scripts/materialize --help`, supply temporary semantic JSON, and bind
either no predecessor or one exact Observe/Finish Account. The deterministic
Tool creates the stable output. Do not hand-author or patch stable JSON.

Ordinary use does not require reading the CUE contract or Tool source. If the
Tool refuses input, correct the reported public field or relation; do not
bypass the contract.
