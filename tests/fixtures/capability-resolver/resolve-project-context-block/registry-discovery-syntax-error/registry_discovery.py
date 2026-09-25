#!/usr/bin/env python3
"""T-003 fixture stub: a co-located `registry_discovery.py` sibling that
fails to import for a reason OTHER than `ImportError` -- deliberately
invalid syntax, raising `SyntaxError` at import time (this file is never
executed as a script; only imported). Confirmation-panel Minor
(Anthropic, security-spec.md B5): `_discover_registry`'s own `except
ImportError` previously let a `SyntaxError` (or any other module-scope
exception) escape uncaught -- a raw Python traceback with no
`capability-resolver:` diagnostic line, no Resolver Evidence, and (since
a `SyntaxError`'s own `str()` embeds the failing file's absolute path) a
B5 no-local-path-in-committed-output containment bypass. Widened to
`except Exception`, interpolating only the exception's own CLASS NAME.
This fixture proves the widened catch closes the class, not merely the
single `ImportError` instance the sibling `registry-discovery-
unimportable` fixture already covers -- both produce byte-identical
canonical output (the fixed `contract-discovery-failed` detail carries no
exception-specific text at all)."""
def this_is_invalid_python_syntax(
