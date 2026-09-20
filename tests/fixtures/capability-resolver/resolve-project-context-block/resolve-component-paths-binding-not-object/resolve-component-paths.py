#!/usr/bin/env python3
"""T-003 fixture stub (route-(a) cross-model panel round-5 closure):
returns a zero-exit payload whose `context_binding` is a truthy
NON-OBJECT (a bare string). The step-4 parse read
`(parsed.get("context_binding") or {}).get("ownership_digest")` -- a
truthy scalar/array there escaped the `or {}` fallback and crashed
`.get` with an uncaught AttributeError instead of the required
`dependency-output-malformed` Block (the same uncaught-crash class the
rounds-2/3 and cycle-7 fixes closed at the evaluate-predicate site).
Asserts the binding is type-checked before field access, Blocking under
the step-4 site's existing canonical sentence."""
import sys

sys.stdout.write(
    '{"affected_components": ["comp-a"], "context_binding": "bogus"}'
)
sys.exit(0)
