# Observe document protocol

Observe materializes one immutable opening Account and its observation report,
not an append-only journal.

The temporary input selects `bootstrap` or `iterate` and supplies the Account
core: subject, boundary, cutoff, source references, evidence delta, current
items, and retired predecessors. Each current item declares:

- `retained`, `changed`, or `added` impact and any predecessor identity;
- continuity reason;
- epistemic kind and `aligned`, `gap`, `conflict`, or `unknown` state;
- minimum supported statement and source references;
- `none`, `goal-candidate`, `retain`, or `external` route.

Bootstrap uses no predecessor, contains only added items, and retires nothing.
Iteration binds one exact Observe or Finish Account. Subject and boundary must
equal the predecessor. Every prior item occurs exactly once as retained,
changed, or retired. Changed, added, and retired entries cite delta evidence.

The Account items and states retain the complete gap inventory. Routes retain
external destinations and possible opportunities. The observation surface is
the derived opening report: it generates the aggregate status and
Goal-candidate index without selecting a Goal or creating a fifth storage
strategy.

The contract also generates item identities, revision, content identity, and
exact predecessor binding. Run the public `--help` for the exact current field
names and command syntax.
