# Goal result contract

The AI authors only this temporary semantic input:

```json
{
  "align_item_ids": ["item ID from the bound Align"],
  "objective": "observable desired state",
  "target": "exact object identity, version, and boundary",
  "source_refs": ["stable source reference"],
  "evidence_cutoff": {
    "at": "cutoff before observing this attempt's result",
    "included_refs": ["evidence admitted before the cutoff"]
  },
  "baseline_refs": ["exact baseline reference"],
  "scope": ["authorized in-scope result"],
  "non_goals": ["explicit exclusion"],
  "execution_envelope": {
    "authorization_ref": "authorization source",
    "authorization_scope": "authorized purpose and action boundary",
    "authorization_claim_limit": "what the source does and does not prove",
    "resources": ["resource identity or explicit none"],
    "budget": "budget ceiling",
    "maximum_side_effects": ["maximum permitted effect"],
    "stop_conditions": {
      "completed": "completion stop",
      "paused": "pause stop",
      "failed": "failure stop",
      "cancelled": "cancellation stop"
    },
    "incomplete_deliverable": "stable evidence and exact resume entrance"
  },
  "acceptance_points": [
    {
      "statement": "result condition contributing to the Goal verdict",
      "required_evidence": ["actual-result evidence"],
      "judge": {
        "kind": "self | independent-agent | script | human",
        "claim_limit": "maximum conclusion supported by this judge"
      },
      "acceptance": {
        "observable": "variable to observe",
        "conditions": ["applicable condition, including explicit none"],
        "window": "observation window",
        "expected": "predicted value or range",
        "falsifier": "observation that makes the point non-pass",
        "comparison_method": "how actual and expected are compared",
        "sampling_rule": "population and sampling rule or full census"
      }
    }
  ],
  "control_contracts": [
    {
      "statement": "execution condition contributing to the Goal verdict",
      "required_evidence": ["actual-method and trace evidence"],
      "judge": {
        "kind": "self | independent-agent | script | human",
        "claim_limit": "maximum conclusion supported by this judge"
      },
      "controlled_variable": "variable kept within bounds",
      "allowed_domain": ["permitted value, range, or state"],
      "forbidden_drift": ["change that makes the control non-pass"],
      "required_trace": ["trace that must exist"],
      "check_method": "how actual state and allowed domain are compared",
      "check_timing": "invariant | terminal",
      "on_non_pass": "stop and incomplete-delivery route"
    }
  ],
  "blockers": [],
  "unknowns": []
}
```

`acceptance_points` must be nonempty when the Goal is frozen.
`control_contracts` may be empty. An explicit sentence is required even when
an acceptance point has no special condition. Rust adds each `point_id` and
`control_id` and derives `status`:

- nonempty `blockers` -> `not-frozen`;
- otherwise nonempty `unknowns` -> `unknown`;
- otherwise -> `frozen`.

The stable envelope is `k4-goal-result/v2` and contains an exact Align binding.
