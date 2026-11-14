#!/usr/bin/env bash
# Shared-engine behavior and installed-runtime conformance (historical entry point).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
ok() { printf 'ok: %s\n' "$1"; }
bad() { printf 'not ok: %s\n' "$1" >&2; exit 1; }
if PYTHONDONTWRITEBYTECODE=1 python3 - "$ROOT" <<'PYEOF'
import importlib.util
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
pairs = [
    (True, 1, False), (False, 0, False), (1, 1.0, True),
    (0, -0.0, True), (None, None, True), ("1", 1, False),
    ([True], [1], False), ({"a": True}, {"a": 1}, False),
    ({"a": [1, {"b": 0}]}, {"a": [1.0, {"b": -0.0}]}, True),
    ({"a": 1, "b": 2}, {"b": 2, "a": 1.0}, True),
    ([], {}, False), ([1], [1, 2], False), ({"a": 1}, {"b": 1}, False),
    (9007199254740993, 9007199254740992, False),
]
for name in ("validate-facet-manifest", "validate-capability-summary", "validate-context-projection"):
    spec = importlib.util.spec_from_file_location(name, root / "plugins/sdd-quality-loop/scripts" / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    for left, right, equal in pairs:
        for instance, schema, expected in (
            (left, {"const": right}, equal),
            (left, {"enum": [right]}, equal),
            ([left, right], {"type": "array", "uniqueItems": True}, not equal),
        ):
            diagnostics = []
            module._validate(instance, schema, schema, "", diagnostics)
            assert (not diagnostics) == expected, (name, instance, schema, diagnostics)
print("126 equality conformance cases passed")
PYEOF
then
    ok "JSON Schema const, enum and uniqueItems equality conforms across all three engines"
else
    bad "JSON Schema equality conformance failed"
fi


python3 "$ROOT/tests/lib/shared-schema-runtime-check.py"
