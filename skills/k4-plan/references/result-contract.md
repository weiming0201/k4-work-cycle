# Plan result contract

The AI authors only this temporary semantic input:

```json
{
  "difference": "frozen difference between Baseline and Goal",
  "route": {
    "claim": "falsifiable selected-route claim",
    "supporting_refs": ["supporting source"],
    "counter_refs": []
  },
  "operations": [
    {
      "depends_on_indices": [],
      "satisfies": ["Goal point ID, or empty for an enabling operation"],
      "controlled_by": ["Goal control ID, or empty when none applies"],
      "action_ref": "declared external Action or Tool",
      "responsible_ref": "responsible executor",
      "input_refs": ["input identity"],
      "output_refs": ["expected output identity"],
      "permission_refs": ["permission reference"],
      "resource_refs": ["resource identity or explicit none"],
      "maximum_side_effects": ["maximum permitted effect"],
      "pre_checks": ["eligibility check"],
      "post_checks": ["result check"],
      "idempotency": "duplicate-effect and safe retry rule",
      "retry_limit": 0,
      "recovery": "recovery position and method"
    }
  ],
  "parallel_groups": [
    {
      "operation_indices": [0, 2],
      "reason": "why concurrency is useful and safe",
      "guards": ["write, resource, evidence, permission and effect guard"]
    }
  ],
  "blockers": [],
  "unknowns": []
}
```

`depends_on_indices` contains zero-based indexes of earlier operations in the
global `operations` array. Rust replaces them with generated operation IDs.
`operation_indices` also addresses the global array; Rust replaces it with
stable IDs. Empty `parallel_groups` is valid. A present group needs at least
two operations, a reason, nonempty guards, and no dependency path between any
pair.

Rust derives this read-only coverage index:

```json
{
  "coverage": {
    "acceptance": [
      {"point_id": "Goal point ID", "operation_ids": ["mapped operation ID"]}
    ],
    "controls": [
      {"control_id": "Goal control ID", "operation_ids": ["mapped operation ID"]}
    ]
  }
}
```

When executable, every Goal acceptance point and control contract must have at
least one mapped operation. Rust derives `status`:

- nonempty `blockers` -> `not-executable`;
- otherwise nonempty `unknowns` -> `unknown`;
- otherwise -> `executable`.

The stable envelope is `k4-plan-result/v2` and contains an exact Goal binding.
