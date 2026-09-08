# Plan result contract

Author the `content` object below as the Candidate. Omit `goal_ref` and
`goal_sha256`: the freeze Tool derives both from the exact Goal file after that
Goal passes its own validator.

```json
{
  "plan_id": "ref-safe-id",
  "version": "version-ref",
  "supersedes": null,
  "status": "executable | not-executable | unknown",
  "source_refs": ["stable source reference"],
  "difference": "frozen difference between Baseline and desired outcome",
  "candidate_routes": [
    {
      "route_id": "r1",
      "claim": "falsifiable route claim",
      "supporting_refs": ["supporting evidence reference"],
      "counter_refs": ["counter-evidence reference"],
      "expected_effects": ["expected effect and affected boundary"],
      "rejected_reason": null
    }
  ],
  "selected_route_id": "r1",
  "nodes": [
    {
      "point_id": "exact Goal point_id",
      "operations": [
        {
          "operation_id": "op1",
          "depends_on": [],
          "inputs": ["input identity"],
          "action": "bounded operation",
          "outputs": ["output identity"],
          "responsible": "responsible executor",
          "ability_refs": ["Ability or Tool reference"],
          "permission_refs": ["permission reference"],
          "resources": ["resource identity or declared none"],
          "maximum_side_effects": ["maximum allowed effect"],
          "pre_checks": ["check before operation"],
          "post_checks": ["check after operation"],
          "idempotency": "idempotency or duplicate-effect rule",
          "retry_limit": 0,
          "recovery": "recovery location and method",
          "next": ["next operation id or stop entrance"],
          "stop_conditions": ["operation stop condition"]
        }
      ],
      "result_destination": "external State or History destination",
      "on_finding": "non-pass delivery and stop route",
      "on_unknown": "unknown delivery and stop route"
    }
  ],
  "edges": [
    {
      "from_point_id": "predecessor Goal point_id",
      "to_point_id": "dependent Goal point_id",
      "reason": "why predecessor pass is necessary",
      "guards": ["contract that must still hold"],
      "on_non_pass": "where the dependent point stops and what is delivered"
    }
  ],
  "parallel_groups": [
    {
      "point_ids": ["independent-point-a", "independent-point-b"],
      "reason": "why concurrent execution is useful and safe",
      "guards": ["write, resource, evidence, permission and effect guard"]
    }
  ],
  "unknowns": []
}
```

`nodes` must contain every Goal point ID exactly once and no other point. Both
the point graph and each operation graph are acyclic. `executable` requires a
selected route, nonempty operations for every point and no blocking unknowns.
An empty `edges` or `parallel_groups` list is valid when the exact Goal permits
it. A changed route or graph requires a new Plan version and `supersedes`.
