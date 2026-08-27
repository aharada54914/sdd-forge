#!/usr/bin/env python3
"""Fixture stub: always fails, emitting distinctive garbage on stderr.

Stands in for canonicalize-sdd-yaml to prove validate-resolver-evidence never
copies a dependency subprocess's own raw stderr into its own diagnostic line
(security-spec.md B5 / REQ-005 dual-runtime byte-identity).
"""
import sys

sys.stderr.write(
    "canonicalize-sdd-yaml: CANARY_RAW_STDERR_LEAK_9f3b at /Users/secret-operator/private/leak-target.yaml line 42\n"
)
sys.exit(3)
