# Align result contract

The AI authors only this temporary semantic input:

```json
{
  "subject": "bounded observed subject",
  "boundary": "included and excluded observation boundary",
  "cutoff": "observation cutoff",
  "source_refs": ["stable source or evidence reference"],
  "items": [
    {
      "state": "aligned | gap | conflict | unknown",
      "statement": "minimum supported statement",
      "evidence_refs": ["reference declared in source_refs"],
      "uses_run": false,
      "route": "none | goal-candidate | retain | external",
      "route_ref": null
    }
  ]
}
```

Use `uses_run: true` only when the generator receives `--run`. At least one
item must use a supplied Run. `external` alone requires a non-null
`route_ref`; every other route requires `null`.

The generator adds `item_id` to every item and derives `status` as follows:

- any `unknown` item -> `unknown`;
- otherwise any `gap` or `conflict` -> `open`;
- otherwise -> `aligned`.

Every declared `source_ref` must be cited by at least one item. This proves
coverage of the declared input set only. The stable envelope is
`k4-align-result/v1` and contains an optional exact Run binding.
