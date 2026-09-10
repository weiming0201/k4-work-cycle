# Observe document protocol

Observe materializes one immutable opening Account and its observation report,
not an append-only journal or a replacement for the observed Assets.

The temporary input selects `bootstrap` or `iterate` and supplies the Account
core: subject, boundary, cutoff, source references, declared observation
lenses, evidence delta, current items, and retired predecessors. Each current
item belongs to one declared lens and declares:

- `retained`, `changed`, or `added` impact and any predecessor identity;
- continuity reason;
- epistemic kind and `aligned`, `gap`, `conflict`, or `unknown` state;
- minimum supported statement and source references;
- `none`, `goal-candidate`, `retain`, or `external` route.

Bootstrap uses no predecessor, contains only added items, and retires nothing.
Iteration binds one exact Observe or Finish Account. Subject and boundary must
equal the predecessor. Every prior item occurs exactly once as retained,
changed, or retired. Changed, added, and retired entries cite delta evidence.

The Account is the unique general ledger for the bounded subject. Each lens is
a source-bound view over the same evidence, not a separate authority. The
observation surface generates the aggregate status, Goal-candidate index, and
the exact lens-to-item index without selecting a Goal. Every declared lens has
at least one current item and every item belongs to one declared lens.

The contract also generates item identities, revision, content identity, and
exact predecessor binding. Run the public `--help` for the exact current field
names and command syntax.
