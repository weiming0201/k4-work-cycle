# Goal document protocol

Goal is one immutable set of terminal-state audit points for one exact Align.

The temporary semantic input contains:

- `align_item_ids`: nonempty selection from the bound Align's generated
  `goal_candidate_ids`;
- `objective`, `target`, `baseline_refs`, `scope`, and `non_goals`;
- `source_refs` and an `evidence_cutoff` fixed before observing the attempt;
- an `execution_envelope` containing authorization, `available_tools`,
  resources, budget, maximum effects, four stop conditions, and the incomplete
  deliverable;
- `acceptance_points`, each with observable, conditions, window, expected
  value, falsifier, comparison method, sampling rule, required evidence, and a
  bounded judge;
- `control_contracts`, each with controlled variable, allowed domain,
  forbidden drift, trace, check method, invariant or terminal timing, required
  evidence, and a bounded judge;
- explicit `blockers` and `unknowns`.

The contract generates every point and control identity. A Goal is `frozen`
only when blockers and unknowns are empty and at least one acceptance point
exists. A nonempty blocker yields `not-frozen`; otherwise a nonempty unknown
yields `unknown`.

Judges are `self`, `independent-agent`, `script`, or `human`; the kind
does not expand its declared claim limit. The available Tool list freezes what
a later Plan may select. The Goal contains no operation, dependency, path
mutation, retry, or actual result.
