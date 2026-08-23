#!/usr/bin/env python3
"""T-003 fixture stub (cross-model panel remediation, Major #2: steps 7-8
abort paths must forward already-collected `warn_diagnostics`). Standing
in for the real `evaluate-predicate` for exactly this fixture's own two
capabilities, evaluated in Registry-declaration order against the
identical single affected component (comp-a):

  1st invocation (cap-warn-first's own trigger, `characteristics.
  auto_update equals true` against `{"characteristics": {"pii": true}}`)
  returns a FIXED `{result, evidence}` document -- byte-identical to the
  REAL evaluate-predicate.py's own output for this exact predicate/
  properties pair (confirmed by direct invocation before authoring this
  fixture: `{"evidence": [{"operator": "equals", "outcome": "warn",
  "path": "characteristics.auto_update", "reason": "missing-path"}],
  "result": false}`) -- so `_evaluate_capabilities` genuinely collects one
  `severity: "warn"` diagnostics[] entry into `warn_diagnostics` before it
  ever reaches cap-fails-second.

  2nd invocation (cap-fails-second's own trigger) fails with a generic
  non-zero exit and NO `PREDICATE_SCHEMA_ERROR` stderr token, so it maps
  to `DependencySubprocessFailed`, not the `PREDICATE_SCHEMA_ERROR`/
  `RegistryValidationFailed` path a sibling fixture (evaluate-predicate-
  schema-error) already covers -- proving `_evaluate_capabilities`'s own
  already-collected `warn_diagnostics` survive an ABORT, not only a clean
  completion.
"""
import json
import sys
from pathlib import Path

MARKER = Path(__file__).resolve().parent / ".t003-evaluate-predicate-called"

FIRST_CALL_OUTPUT = {
    "result": False,
    "evidence": [
        {"operator": "equals", "outcome": "warn", "path": "characteristics.auto_update", "reason": "missing-path"}
    ],
}


def main():
    if MARKER.exists():
        sys.stderr.write("FIXTURE_INJECTED_FAILURE: evaluate-predicate failed on its second invocation\n")
        return 1
    MARKER.write_text("called\n", encoding="utf-8")
    sys.stdout.write(json.dumps(FIRST_CALL_OUTPUT, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
