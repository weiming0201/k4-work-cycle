# K4 Goal and Plan

This Resource provides two Agent Skills:

- `k4-goal` freezes one bounded Goal as a complete set of acceptance points.
- `k4-plan` turns that frozen set into an executable, guarded dependency graph.

The normative design is in [`DESIGN.md`](./DESIGN.md). The Skills are derived
from that design and from `resource-033@bb64afe05f1f7d447ff17ace70113a8671d82566`.
They do not depend on Agent Frame. A compatible consumer may later register or
project them as external Actions without acquiring their authority; compatibility
must be established for that consumer rather than inferred from this Resource.

Run `python3 tests/run.py` to exercise the canonical Goal and Plan validators,
their exact binding, point coverage, graph contracts, and principal refusal
paths. Passing the harness does not mechanically prove semantic sufficiency,
authorization, executability in a particular Host, or portability.
