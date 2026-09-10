# 0.4.1 to 0.5.0 migration

Release `0.5.0` adds semantic information that cannot be inferred from a
`0.4.1` chain: the complete Goal execution envelope, each judge's sourceable
identity, and the permissions and resources used by each emergency patch.
Migration therefore requires an explicit policy rather than inventing values.

The policy is one JSON object:

```json
{
  "execution_envelope": {
    "available_tools": ["tool://..."],
    "permission_refs": ["authorization://..."],
    "read_refs": ["asset://..."],
    "write_refs": ["artifact://..."],
    "resources": ["resource://..."],
    "maximum_side_effects": ["..."]
  },
  "judge_refs": {
    "point-OLD_ID": "tool://...",
    "control-OLD_ID": "agent://..."
  },
  "patches": {
    "op-OLD_ID": {
      "permission_refs": ["authorization://..."],
      "resource_refs": ["resource://..."]
    }
  }
}
```

`judge_refs` must exactly cover every old Goal point and control. `patches`
must exactly cover the operations that have an emergency-patch event; it is an
empty object when the Run contains no patch. The current contracts decide
whether each supplied value is legal—for example, every Plan and patch boundary
must be contained in `execution_envelope`.

Run:

```text
tools/migrate-0.4.1-to-0.5.0 \
  --observe observe.json \
  --goal goal.json \
  --plan plan.json \
  [--run-log run.jsonl] \
  [--finish finish.json] \
  --policy policy.json \
  --output-dir absent-directory
```

Goal and Plan are always migrated. Run is optional; Finish requires Run. The
Tool verifies the supplied old envelopes and Run hash chain, checks their exact
bindings, re-materializes the new Goal and Plan, remaps generated identities,
and replays supplied Run events through the new append interface. When Finish
is supplied it is re-materialized from the new ledger.

Migration never edits the source chain and never claims that old and new
content digests are equal. `migration.json` records the policy digest, every
schema transition, and the old and new file digests. A failed migration is not
a completed migration; use a new absent destination after correcting its
reported cause.
