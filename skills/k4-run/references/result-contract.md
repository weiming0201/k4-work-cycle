# Run result contract

The AI authors only this temporary semantic input after actual execution:

```json
{
  "operation_results": [
    {
      "operation_id": "exact Plan operation ID",
      "result": "pass | Finding | unknown | not-run",
      "eligibility_refs": ["actual dependency, authority, resource, and pre-check evidence"],
      "actual_output_refs": ["actual output reference"],
      "evidence_refs": ["result or non-pass evidence"],
      "trace_refs": ["actual invocation or stop trace"]
    }
  ],
  "acceptance_results": [
    {
      "point_id": "exact Goal acceptance point ID",
      "result": "pass | Finding | unknown | not-run",
      "actual_refs": ["actual result reference"],
      "comparison_refs": ["comparison result"],
      "evidence_refs": ["verdict evidence"]
    }
  ],
  "control_results": [
    {
      "control_id": "exact Goal control ID",
      "result": "pass | Finding | unknown | not-run",
      "actual_refs": ["actual controlled-variable reference"],
      "trace_refs": ["required execution trace"],
      "comparison_refs": ["control comparison result"],
      "evidence_refs": ["verdict evidence"]
    }
  ],
  "budget_evidence_refs": ["actual budget evidence"],
  "side_effect_evidence_refs": ["actual effect evidence"],
  "stop_state": "completed | paused | failed | cancelled",
  "resume_ref": null
}
```

Rust adds `required_check_timing` to each stable control result from the exact
bound Goal. Semantic input must not author this field.

Every Plan operation, Goal acceptance point, and Goal control must occur
exactly once. A `pass` operation requires eligibility, output, evidence, and
trace references. A `pass` acceptance or control requires actual, comparison,
and evidence references; control pass also requires trace. `Finding` requires
evidence. `not-run` has no implied success.

Any non-`not-run` operation requires all declared dependencies to pass. An
acceptance cannot pass until every operation mapped to it passes. An invariant
control cannot remain `not-run` after any operation mapped to it has run. A
terminal control may remain `not-run` until its final check.

Rust derives the aggregate `result`:

- any `Finding` -> `Finding`;
- otherwise any `unknown` or `not-run` -> `unknown`;
- otherwise -> `pass`.

`pass` and `stop_state=completed` must coincide. Completed requires
`resume_ref: null`; every other stop requires a non-null resume reference.
The stable envelope is `k4-run-result/v1` and contains exact Goal and Plan
bindings. Automatic reuse of older Run evidence is intentionally absent.
