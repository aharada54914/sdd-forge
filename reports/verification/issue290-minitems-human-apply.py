"""Human-only, hash-pinned repair; preserves review and Git state."""
import hashlib
import importlib.util
import json
from pathlib import Path
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / "plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py"
EXPECTED = "01411086bb889967f62b33249a0f42b0399f1945ec98f7f0a25f8576fe46bcd1"


def check(module):
    validate = module._schema_validate
    assert validate({"type": "array", "minItems": 1}, [])
    assert not validate({"type": "array", "minItems": 1}, ["x"])
    assert not validate({"type": "array", "minItems": 0}, [])
    assert not validate({"type": "array"}, [])
    assert not validate({"minItems": 1}, "not-an-array")
    schema = json.loads((ROOT / "contracts/concept-test.v1.schema.json").read_text())
    assert validate(schema["properties"]["inputs"], [])
    print("PASS: six minItems boundary checks")


def load():
    sys.dont_write_bytecode = True
    spec = importlib.util.spec_from_file_location("sidecar", TARGET)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


if sys.argv[1:] == ["--test"]:
    check(load())
elif sys.argv[1:] == ["--apply"]:
    before = TARGET.read_bytes()
    if hashlib.sha256(before).hexdigest() != EXPECTED:
        raise SystemExit("STOP: source hash changed; no application")
    old = b'    if isinstance(instance, dict):\n'
    new = (
        b'    if isinstance(instance, list) and len(instance) < schema.get("minItems", 0):\n'
        b'        errors.append("%s: fewer than minItems %d" % (path, schema["minItems"]))\n\n'
        + old
    )
    comment = b'# `format` is deliberately NOT implemented.'
    if before.count(old) != 1 or before.count(comment) != 1:
        raise SystemExit("STOP: replacement is not unique; no application")
    after = before.replace(old, new).replace(comment, b'# `format` is deliberately annotation-only.')
    compile(after, str(TARGET), "exec")
    module = load()
    if module._schema_validate({"type": "array", "minItems": 1}, []):
        raise SystemExit("STOP: expected original defect not reproduced; no application")
    print("RED confirmed: original validator accepts empty array with minItems=1")
    backup = Path(tempfile.mkdtemp(prefix="sdd290-minitems-backup-")) / TARGET.name
    backup.write_bytes(before)
    if TARGET.read_bytes() != before:
        raise SystemExit(f"STOP: concurrent source change; backup={backup}")
    TARGET.write_bytes(after)
    if TARGET.read_bytes() != after:
        raise SystemExit(f"STOP: readback mismatch; backup={backup}")
    print("Backup:", backup)
    print("SHA256:", hashlib.sha256(after).hexdigest())
    check(load())
    print("Applied one source file; full regressions, review, CI and merge remain pending.")
else:
    raise SystemExit("Usage: python3 issue290-minitems-human-apply.py --apply | --test")
