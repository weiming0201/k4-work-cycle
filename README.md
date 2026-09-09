# K4 Work Cycle Agent Extension

This Resource packages four different document protocols as four peer Agent
Skills:

- `k4-align`: iterates a full account of the current evidenced situation;
- `k4-goal`: freezes one set of terminal-state audit points;
- `k4-plan`: freezes one operation DAG between baseline and predicted terminal
  state;
- `k4-run`: appends actual execution events and projects current Run state.

Read [`WORKFLOW.md`](./WORKFLOW.md) for the common semantics and
[`DESIGN.md`](./DESIGN.md) for the implementation boundary.

## Source layout

```text
WORKFLOW.md
DESIGN.md
README.md
manifest.cue
manifest.json
tools/stable-result
skills/
  k4-align/{SKILL.md,assets/,references/,scripts/}
  k4-goal/{SKILL.md,assets/,references/,scripts/}
  k4-plan/{SKILL.md,assets/,references/,scripts/}
  k4-run/{SKILL.md,assets/,references/,scripts/}
tests/conformance.py
```

The only fixed executable dependency is `cue v0.17.1`. The shared Tool has no
stage semantics; each Skill supplies its own CUE contract.

## Mechanical interface

The Skill-local scripts are the public entrypoints. Align, Goal, and Plan each
materialize a new immutable document. Run appends one event at a time and
projects the ledger into a regenerable derived view. Every stable output is
written by the shared Tool; semantic JSON supplied by an Agent remains
temporary input.

Run the preserved contract cases from the Resource root:

```text
python3 tests/conformance.py
```

The conformance test uses isolated temporary directories and must not write build
artifacts into this Resource.

Mechanical validation proves only the declared structure, bindings, write
semantics, and state-transition rules. It does not prove that source evidence
is true, the chosen Goal or Plan is sufficient, or an external action was
authorized.
