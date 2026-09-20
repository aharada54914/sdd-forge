#!/usr/bin/env python3
"""T-003 fixture stub (gate cycle-7 Critical closure): deterministically
returns a zero-exit {result, evidence} payload whose top-level node is
fully evidenceNode-contract-valid but whose nested child carries an
UNHASHABLE value (`"operator": []`) in an enum-checked field. The
round-3 contract-mirror validation tested enum membership with a bare
`x in <frozenset>`, which HASHES x -- so a JSON array or object in
`operator`/`outcome` raised an uncaught `TypeError: unhashable type`
instead of returning False: no canonical `dependency-output-malformed`
Block, no Resolver Evidence written, a raw traceback on stderr -- the
same failure shape the round-2 panel already blocked as an
AttributeError. Asserts the enum tests are hash-safe (isinstance-str
guarded) so this payload Blocks up front like every other malformed
tree."""
import sys

sys.stdout.write(
    '{"result": true, "evidence": [{"operator": "all", "path": null,'
    ' "outcome": "match", "children":'
    ' [{"operator": [], "path": "characteristics.x", "outcome": "match"}]}]}'
)
sys.exit(0)
