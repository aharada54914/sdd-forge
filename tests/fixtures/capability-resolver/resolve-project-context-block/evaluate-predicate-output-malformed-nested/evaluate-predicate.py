#!/usr/bin/env python3
"""T-003 fixture stub (route-(a) cross-model panel round-2 closure):
deterministically returns a zero-exit {result, evidence} shape whose
top-level `evidence[]` elements ARE objects -- passing an element-wise
top-level check -- but whose nested `children` array carries a bare
string (`["x"]`) instead of evidence nodes. Asserts step 7's
evidence-shape validation is RECURSIVE (design.md step 7's malformed-
output Block covers the whole tree), raising `dependency-output-
malformed` instead of `_iter_warn_nodes`'s `.get()` crashing with an
uncaught AttributeError on the bare string at depth 1 -- the exact
fail-open the openai panelist's round-2 Major named."""
import sys

sys.stdout.write('{"result": true, "evidence": [{"outcome": "pass", "children": ["x"]}]}')
sys.exit(0)
