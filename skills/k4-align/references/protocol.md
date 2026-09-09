# Align document protocol

Align is a versioned full account, not an append-only history.

The temporary semantic input is:

```json
{
  "mode": "bootstrap | iterate",
  "subject": "bounded subject identity",
  "boundary": "included and excluded observation boundary",
  "cutoff": "evidence cutoff",
  "source_refs": ["source or evidence reference"],
  "delta": {
    "summary": "what changed in this iteration",
    "evidence_refs": ["evidence responsible for this iteration"]
  },
  "items": [
    {
      "change": "retained | changed | added",
      "previous_item_id": null,
      "change_reason": "why this continuity relation holds",
      "state": "aligned | gap | conflict | unknown",
      "statement": "minimum supported current statement",
      "evidence_refs": ["reference in source_refs"],
      "route": "none | goal-candidate | retain | external",
      "route_ref": null
    }
  ],
  "retired": [
    {
      "previous_item_id": "item ID from the bound Align",
      "reason": "why it is absent from the new full account",
      "evidence_refs": ["reference in delta.evidence_refs"]
    }
  ]
}
```

For `bootstrap`, pass `--null-bind previous_align`; every item is `added`,
`previous_item_id` is null, and `retired` is empty.

For `iterate`, pass `--bind previous_align=<prior-align.json>`. The subject
and boundary remain the same. Every prior item occurs exactly once as the
predecessor of a retained or changed item, or in `retired`. A retained item
has the same generated identity; a changed item has a different identity.
Added items have no predecessor. Every changed, added, or retired entry cites
at least one delta evidence reference.

All source references are used. Routes other than `external` require a null
`route_ref`; `external` requires a nonempty destination. The contract
generates item identities, revision, Goal-candidate index, aggregate status,
and exact predecessor binding.
