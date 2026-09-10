---
name: k4-observe
description: Create the next sourced opening Account and its gap/opportunity report before Goal selection or after Finish. Use at cold start or when evidence may have changed; do not define acceptance, choose operations, repair the object, or close an attempt.
---

# K4 Observe

Use this Skill only to create the next opening Account and its observation
report from current reality.

## Boundary

- Bootstrap without a predecessor, or bind one exact Account produced by
  Observe or Finish.
- On iteration keep the subject and observation boundary unchanged. A changed
  subject or boundary requires bootstrap, not an iteration.
- Admit a declared evidence delta and account for every prior item as retained,
  changed, or retired; mark every new item added.
- Keep fact, source statement, inference, preference, gap, conflict, and unknown
  distinguishable. `goal-candidate` exposes a possibility only.
- Treat the Account as the general ledger. Its observation report is a derived
  gap/opportunity view; it does not select which opportunity becomes the Goal.
- Do not mutate the observed object, set Goal acceptance, choose a Plan, execute
  work, or judge a finished attempt.

## Form the semantic input

State the subject, included and excluded boundary, cutoff, complete sources,
and this observation's evidence delta. For every current item state its impact,
predecessor relation, epistemic kind, current state, minimum supported claim,
evidence, and route. List every retired predecessor with its reason and delta
evidence.

The current items and their states are the gap inventory. Routes identify
retained matters, external destinations, and possible Goal inputs. The
generated observation surface indexes the current status and Goal candidates;
it does not create another store.

Bootstrap has only added items and no retired predecessor. Iteration accounts
for every predecessor item exactly once. Changed, added, and retired entries
cite this iteration's delta evidence.

## Materialize

Run `scripts/materialize --help` before authoring input and use that output as
the field vocabulary. Then give temporary semantic JSON to the script and bind
either no predecessor or one exact Observe/Finish Account. The script creates
the absent stable output through the deterministic Tool.

Do not hand-author or patch the stable Account. Ordinary use does not require
reading the CUE contract or Tool source. If materialization refuses input,
correct the named public field or relation; do not reverse-engineer or bypass
the contract.
