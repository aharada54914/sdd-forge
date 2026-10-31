#!/usr/bin/env python3
"""T-003 fixture stub for the `omits-components` projection-success case
only.

`resolve-component-paths.py`'s own restricted YAML parser (Epic A3,
verified directly against the live script) requires a source document's own
`components` key to be explicitly present -- it does not default an
entirely-omitted key to an empty list, unlike this feature's own
`contracts/project-context.schema.json` (where `components` is optional).
`omits-components.yaml` deliberately omits `components` to exercise this
feature's own step 3 default-fill rule (REQ-003) and must stay byte-for-byte
unedited for that reason, so this stub stands in for step 4 on that one
fixture only: a fixed, always-succeeding, zero-affected-component result,
letting steps 4-9 complete as a legitimate no-op without touching Epic A3's
own file or this feature's own T-002-authored fixture content."""
import sys

sys.stdout.write(
    '{"affected_components": [], '
    '"context_binding": {"ownership_digest": '
    '"sha256:0000000000000000000000000000000000000000000000000000000000000000"}}'
)
sys.exit(0)
