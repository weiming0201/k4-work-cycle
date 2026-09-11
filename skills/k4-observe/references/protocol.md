# Observe document protocol

Observe materializes one immutable opening Account and its observation report,
not an append-only journal or a replacement for the observed Assets.

The predecessor binding selects bootstrap or iteration. Bootstrap input states
the new subject, boundary, cutoff, evidence delta, and initial additions.
Iteration input states only the new cutoff, evidence delta, and any semantic
updates, additions, or retirements. The delta summary and evidence explain why
the revision exists; they are semantic input, not an aggregate source inventory.
An update names one predecessor and supplies its new semantic item; a retirement
names one predecessor and its reason and evidence. Every new or updated item
declares:

- its continuity reason;
- epistemic kind and `aligned`, `gap`, `conflict`, or `unknown` state;
- minimum supported statement and source references;
- `none`, `goal-candidate`, `retain`, or `external` route.

`route_ref` is supplied only for an `external` route. Bootstrap uses no
predecessor and requires at least one addition. Iteration binds one exact
Observe or Finish Account and requires at least one update, addition, or
retirement. Subject and boundary come from the predecessor and cannot be
restated. Unmentioned predecessors are retained mechanically; the caller never
copies them into the delta.

The Tool derives revision, mode, continuity labels and predecessor bindings,
retained items, current source references, current lenses, item identities, the
lens index, and all envelope metadata. Source references are the ordered unique
union of evidence used by current items, retirements, and the declared delta;
they are not a caller-maintained inventory. Non-external routes receive
`route_ref: null` mechanically.

The Account is the unique general ledger for the bounded subject. Each lens is
a source-bound view over the same evidence, not a separate authority. The
observation surface generates the aggregate status, Goal-candidate index, and
the exact lens-to-item index without selecting a Goal. Every declared lens has
at least one current item and every item belongs to one declared lens.

The public entrypoint preflights the whole input before CUE evaluation and
returns all detected errors with field paths. Run its `--help` for the exact
current field names and command syntax.
