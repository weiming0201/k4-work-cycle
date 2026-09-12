# Goal document protocol

Goal is one immutable terminal-audit contract for one exact Observe Account.
Its temporary input distinguishes one selected Goal-candidate from optional
supporting items, then states objective, selection rationale, target, decision
basis, change contract, baselines, scope, non-goals and cutoff; an execution
envelope and Finish closure subset; acceptance points; control contracts; a
boundary-feasibility review; blockers; and unknowns.

The Tool derives the combined Observe item projection and source inventory from
selected and supporting Observe evidence, cutoff references, baselines,
decision and feasibility evidence, and source-bound self or independent judges.
Empty supporting items, non-goals, controls, blockers, and unknowns may be
omitted.

The decision basis records expected benefit, expected cost, downside,
reversibility, information value, bounded confidence, and its sources. The
change contract freezes one task-native direct change, directly changed
positions, derivative effects, affected positions, and frozen positions. The
optional single-facet specialization additionally records one facet and the
state of its six incident positions, but applies only when that topology is
actually selected. An Observe lens is not thereby a control variable.

Boundary feasibility contains exactly seven judgments: subject and boundary,
Account sufficiency, change-surface clarity, execution-envelope sufficiency,
downside control, terminal observability, and failure stop. Each preserves its
binary result, statement, evidence and unknowns. Any failed check makes the
Goal not-frozen; passing means only that Plan may be formed.

Acceptance points contain observable conditions, window, expected value,
falsifier, sampling and comparison, required evidence, and bounded judge.
Controls contain variable, allowed domain, forbidden drift, trace, method,
`invariant` or `terminal` timing, evidence, and judge. The execution envelope
separately freezes tools, permission references, readable and writable
positions, resources, budget, and maximum side effects. Plan, not Goal,
decides what operation follows a failed check.

The closure policy freezes the maximum number and allowed kinds of Finish
closure actions plus their tools, permissions, read/write positions, resources,
and effects. Every field is a subset of the execution envelope; a halted Run
does not create new closure authority.

Judges are self, independent agent, script, or human; every judge has a
sourceable identity and kind never expands the claim limit. Self and
independent-agent identities must occur in Goal sources, script judges must be
available Goal tools, and a human judge must be the Goal authorization source.
A Goal is frozen when blockers are empty, all seven feasibility checks pass,
and at least one acceptance point exists. Unknowns remain explicit annotations
and do not by themselves prevent freezing. It contains no operation,
dependency, mutation, retry, or actual
result. Run `scripts/materialize --help` for exact fields.
