#!/usr/bin/env python3
"""T-003 fixture stub (route-(a) cross-model panel rounds 2-3 closure):
deterministically returns a zero-exit {result, evidence} payload whose
TOP-LEVEL node is fully evidenceNode-contract-valid (operator/path/
outcome present, enum-valid -- so no top-level or field-blind check can
reject it) but whose nested `children` array violates the contract
twice over: the first child is an OBJECT missing the required
`outcome` field (round 3's field-validation Major -- the old
object-ness-only check accepted it and the malformed node flowed on to
be misattributed downstream), and the second child is a bare string
(round 2's recursion Major -- the old top-level-only check let it
crash `_iter_warn_nodes`'s `.get()` with an uncaught AttributeError).
Asserts step 7's shape validation mirrors the bundled evidenceNode
contract (contracts/resolver-evidence.schema.json
#/definitions/evidenceNode) recursively at every depth, Blocking
`dependency-output-malformed` up front. NOTE: the payload deliberately
contains NO bare-string child -- a bare string anywhere is already
rejected by the round-2 structural recursion, so it would mask the
field-validation red; the string-crash class stays locked by the
round-2 mutation-kill log and by the same recursive function's
isinstance check one line above the field checks."""
import sys

sys.stdout.write(
    '{"result": true, "evidence": [{"operator": "all", "path": null,'
    ' "outcome": "match", "children":'
    ' [{"operator": "equals", "path": "characteristics.x"}]}]}'
)
sys.exit(0)
