---
name: k4-align
description: Reconcile one bounded current situation, or one completed K4 Run, into sourced aligned, gap, conflict, and unknown items before choosing the next Goal. Use at cold start or after k4-run; do not use it to define acceptance criteria or perform corrective work.
---

# K4 Align

Align is the entry and return point of `Align -> Goal -> Plan -> Run -> Align`.
It freezes what is currently aligned, different, conflicting, or unknown and
where each item may go next. It does not create a Goal or change the observed
object.

## Input and boundary

Freeze one subject, observation boundary, cutoff, declared source set, and one
or more sourced items. A post-Run Align may additionally bind exactly one
`k4-run-result/v1`; a cold-start or full observation omits it.

`goal-candidate` is only a route label. Do not place a desired outcome,
acceptance criterion, permission, plan, operation, adoption, or write-back in
an Align item.

## Stable result

Read [the result contract](references/result-contract.md), write its temporary
semantic input, then call only this Rust generator from the Skill root:

```text
cargo run --offline --manifest-path ../../kernel/Cargo.toml --bin k4-align-result -- generate --input <semantic-input.json> --output <absent-result.json> [--run <run-result.json>]
```

Rust alone creates the stable JSON structure, item IDs, optional Run binding,
time, aggregate status, digest, canonical bytes, and output file. A rejected
input remains a rejected Candidate; do not hand-author or patch the result.

Stop with an `unknown` item when a source, boundary, classification, or route
cannot be supported. Mechanical success proves only the declared source
coverage and result structure, not that every relevant fact in reality was
observed.
