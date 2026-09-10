---
name: k4-finish
description: Reconcile one halted Run journal into the next closing Account and stage report, preserving bounded judgments, incomplete work, and result placement. Use only after k4-run halts; do not repair, adopt, publish, choose the next Goal, or claim independent audit.
---

# K4 Finish

Use this Skill only to close one bounded attempt truthfully by reconciling its
journal into the general ledger.

## Boundary

- Bind the exact pre-Goal Account, frozen Goal, executable Plan, Run ledger, and
  halted Run projection.
- Reuse the common Account core and treat the attempt outcome as the evidence
  delta. Account for every predecessor item.
- Judge every Goal acceptance point and terminal control from bounded evidence;
  do not infer success from Run reaching its last node.
- Record terminal state, actual result disposition, incomplete deliverable, and
  resume position. Only a completed result has no resume position.
- Treat closure as the complete stage report: it records bounded judgments and
  exact Run reference while the Account records the resulting situation.
- Preserve evidence for a later external audit. Internal reconciliation is not
  independent audit unless a separately authorized auditor supplied evidence.
- Do not execute repair, alter Goal or Plan, append Run events, adopt or publish
  output, or expose/select a future Goal candidate.

## Form the semantic input

Provide the common Account fields: unchanged subject and boundary, new cutoff,
complete sources, attempt delta, current items, and retired predecessors. Add
exact attempt bindings; one bounded result for every Goal acceptance point and
terminal control; terminal state; actual result disposition; incomplete
package; resume information; and the exact Run journal reference.

A completed judgment requires all planned operations, acceptance points, and
controls to pass. Any other truthful state preserves what remains and where a
later attempt can resume. Finish describes actual placement or required
disposition; it does not perform an unplanned side effect or self-certify an
independent audit.

## Materialize

Run `scripts/materialize --help` before authoring input. Give temporary semantic
JSON to the script and bind the exact pre-Goal Account, Goal, Plan, Run ledger,
and halted projection. The deterministic Tool creates one absent stable Finish
Account, which can be consumed by the next Observe.

Do not hand-author or patch stable JSON. Ordinary use does not require reading
the CUE contract or Tool source. Correct named public omissions or
contradictions; do not bypass the contract.
