# Goal document protocol

Goal is one immutable terminal-audit contract for one exact Observe Account.
Its temporary input contains selected Goal-candidate item identities, objective,
target, baselines, scope, non-goals, sources and cutoff; an execution envelope;
acceptance points; control contracts; blockers; and unknowns.

Acceptance points contain observable conditions, window, expected value,
falsifier, sampling and comparison, required evidence, and bounded judge.
Controls contain variable, allowed domain, forbidden drift, trace, method,
`invariant` or `terminal` timing, evidence, judge, and non-pass response.

Judges are self, independent agent, script, or human; kind never expands the
claim limit. A Goal is frozen only when blockers and unknowns are empty and at
least one acceptance point exists. It contains no operation, dependency,
mutation, retry, or actual result. Run public `--help` for exact field names.
