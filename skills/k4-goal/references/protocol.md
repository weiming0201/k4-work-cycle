# Goal document protocol

Goal is one immutable terminal-audit contract for one exact Observe Account.
Its temporary input contains selected Goal-candidate item identities, objective,
selection rationale, target, baselines, scope, non-goals, sources and cutoff;
an execution envelope; acceptance points; control contracts; blockers; and
unknowns.

Acceptance points contain observable conditions, window, expected value,
falsifier, sampling and comparison, required evidence, and bounded judge.
Controls contain variable, allowed domain, forbidden drift, trace, method,
`invariant` or `terminal` timing, evidence, and judge. Plan, not Goal, decides
what operation follows a failed check.

Judges are self, independent agent, script, or human; kind never expands the
claim limit. A Goal is frozen when blockers are empty and at least one
acceptance point exists. Unknowns remain explicit annotations and do not by
themselves prevent freezing. It contains no operation, dependency, mutation,
retry, or actual result. Run `scripts/materialize --help` for exact fields.
