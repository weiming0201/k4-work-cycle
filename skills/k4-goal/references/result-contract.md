# Goal result contract

Author the `content` object below as the Candidate. Use `null` for the contract
that does not match a point's `mode`. The freeze Tool adds the outer result
wrapper, timestamp and digest.

```json
{
  "goal_id": "ref-safe-id",
  "version": "version-ref",
  "supersedes": null,
  "status": "frozen | not-frozen | unknown",
  "target": {
    "identity": "exact object identity",
    "version_ref": "baseline version or content identity",
    "boundary": "included and excluded boundary"
  },
  "desired_outcome": "observable desired state",
  "source_refs": ["stable source reference"],
  "evidence_cutoff": {
    "at": "cutoff description or timestamp",
    "included_refs": ["evidence admitted before the target attempt result"]
  },
  "baseline_refs": ["exact baseline reference"],
  "evidence_claims": [
    {
      "kind": "fact | source-statement | inference | preference | unknown",
      "statement": "claim",
      "source_ref": null
    }
  ],
  "scope": ["authorized in-scope result"],
  "non_goals": ["explicit exclusion"],
  "authorization": {
    "ref": "authorization source",
    "scope": "authorized action boundary",
    "claim_limit": "what this reference does and does not prove"
  },
  "control_envelope": {
    "budget": "budget ceiling",
    "resources": ["resource identity or declared none"],
    "maximum_side_effects": ["maximum allowed effect"],
    "stop_conditions": {
      "completed": "completion stop",
      "paused": "pause stop",
      "failed": "failure stop",
      "cancelled": "cancellation stop"
    },
    "incomplete_deliverable": "stable result, evidence and resume entrance"
  },
  "acceptance_points": [
    {
      "point_id": "p1",
      "mode": "prediction",
      "statement": "result condition that affects the Goal verdict",
      "required_evidence": ["actual-result evidence requirement"],
      "independence": "who or what may judge, with conclusion limits",
      "prediction": {
        "observable": "variable to observe",
        "conditions": ["applicable condition"],
        "window": "observation window",
        "expected": "predicted value or range",
        "falsifier": "observation that makes this point non-pass",
        "result_contract_ref": "frozen source and content identity",
        "comparison_method": "how actual result is compared",
        "sampling_rule": "population and sampling rule, or explicit full census"
      },
      "control": null
    },
    {
      "point_id": "c1",
      "mode": "control",
      "statement": "control condition that affects the Goal verdict",
      "required_evidence": ["actual-method and trace requirement"],
      "independence": "who or what may judge, with conclusion limits",
      "prediction": null,
      "control": {
        "required_method": "frozen control method",
        "allowed_variations": ["explicitly allowed change"],
        "forbidden_drift": ["change that makes this point non-pass"],
        "required_trace": ["trace that must exist"],
        "check_method": "how actual method and trace are compared",
        "on_non_pass": "stop and incomplete-delivery route"
      }
    }
  ],
  "unknowns": []
}
```

For a frozen Goal, `source_refs`, `baseline_refs`, `scope`, resources, maximum
side effects, and `acceptance_points` are nonempty. Point IDs are unique and
ref-safe. A changed semantic field requires a new version and `supersedes`.
