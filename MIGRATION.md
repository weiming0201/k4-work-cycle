# Versioned migration

## 0.9.0 to 0.10.0

Release `0.10.0` changes semantic responsibility and therefore never
reinterprets an existing `0.9.0` chain. Existing Goal v7, Plan v8, Run v7, and
Finish v5 work remains governed by the exact contracts in
`tools/contracts/0.9.0/`; settle an already-running chain there, then begin the
next Account revision with the current entrypoints.

The new obligations cannot be derived safely from old artifacts. A caller must
decide the task-native direct, affected, and frozen positions; any optional
single-facet specialization; the exact Finish closure allowance; which Plan
operations possess an emergency-patch seam; and which actual Finish closure
actions occurred. A new Finish closure ledger also requires one explicit final
halt after zero or more actions; terminality is not inferred from an absent next
event. Finish v6 also rejects settlement evidence that cannot be
traced to the opening Account, Run ledger, or Finish closure ledger. Because
these are semantic decisions and actual historical facts, this release provides
no automatic migration Tool.

## 0.8.0 to 0.9.0

Release `0.9.0` introduces new stable semantic obligations and therefore does
not reinterpret an existing chain in place. New work starts with Observe v3,
then Goal v7, Plan v8, Run event/projection v7, and Finish v5. Existing Observe
v2, Goal v6, Plan v7, Run v6, and Finish v4 artifacts remain valid under the
exact frozen contracts in `tools/contracts/0.8.0/`.

The new fields are not safely inferable from old artifacts: observation
completeness, decision basis, change surface, boundary-feasibility findings,
each operation's local judgment and structured failure handling, and Finish
closure actions, attribution and residual effects all require new semantic
work. For that reason this release supplies no automatic chain migration.
Continue and settle an already-running old chain with the old contracts; then
start the next Account revision through the v0.9.0 Observe entrypoint.

## 0.7.0 to 0.8.0

No stable artifact migration is required. Release `0.8.0` minimized temporary
caller input while retaining the Observe v2, Goal v6, Plan v7, Run v6, and
Finish v4 stable schemas. Existing full inputs remain accepted when their
formerly caller-maintained fields agree with deterministic derivation. New
callers used each v0.8.0 entrypoint's `--help`; v0.9.0 public entrypoints accept
semantic input only.

The minimized Finish entrypoint refuses duplicate or unknown updates,
update-retirement collisions, invalid closing routes, and missing required
terminal judgments before materialization. It derives omitted
`terminal_control_results: []` only for a zero-terminal-control Goal. The Run
entrypoint continues to derive fixed patch metadata but requires every
emergency patch to supply a nonempty actual Finding. These are temporary-input
boundary corrections; stable documents and event schemas do not migrate.

## 0.6.0 to 0.7.0

No stable artifact migration is required. Release `0.7.0` changes only the
temporary semantic input accepted by `k4-observe`: iteration now supplies a
delta instead of reproducing the full Account. Stable Observe documents remain
`k4-observe-document/v2`. Because the Account contract did not change, Observe
may bind existing `k4-finish-document/v2`, v3, or v4 Accounts directly.

Migration Tools target one exact released contract. The frozen target CUE for
`0.5.0` is retained under `tools/contracts/0.5.0/`, so the older migration does
not silently begin producing a newer schema.

## 0.5.0 to 0.6.0

Release `0.6.0` adds a Plan-owned abort response and replaces the three legacy
halt triggers with `plan-complete | abort`. A legacy Plan cannot supply its own
abort response, so migration requires an explicit preserve-only policy:

```json
{
  "on_abort": {
    "mode": "preserve-only",
    "reason": "Why this legacy Plan should preserve evidence only on abort."
  },
  "legacy_abort_source_ref": null
}
```

Set `legacy_abort_source_ref` to a nonempty external or runtime evidence source
only when migrating a Run whose old halt is `blocked` or `cancelled`. The Tool
then inserts an `abort-confirmed` event before the new abort terminal event. A
normal `plan-complete` chain requires no such source.

Run:

```text
tools/migrate-0.5.0-to-0.6.0 \
  --observe observe.json \
  --goal goal.json \
  --plan plan.json \
  [--run-log run.jsonl] \
  [--finish finish.json] \
  --policy policy.json \
  --output-dir absent-directory
```

Goal remains byte-identical. Plan is re-materialized with all legacy
operations in the normal phase and the declared preserve-only response. Run is
replayed with new identities and hash chain; Finish is re-materialized from
that exact ledger.

## 0.4.1 to 0.5.0

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
