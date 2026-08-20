#!/usr/bin/env python3
"""T-003 fixture stub: deterministically unimportable, standing in for a
deployed-script-directory `registry_discovery.py` that cannot be imported
(module missing/broken at that destination). Asserts step 5's own bare
`import registry_discovery` (previously placed OUTSIDE its own `try:`) is
caught and mapped to `contract-discovery-failed`, exit 1, with Resolver
Evidence still written -- never an uncaught ImportError traceback with no
diagnostic line and no Evidence at all."""
raise ImportError("FIXTURE_INJECTED_FAILURE: registry_discovery deliberately unimportable")
