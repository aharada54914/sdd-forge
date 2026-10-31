"""Human-applied receipt checks for the original-path PowerShell observer."""
import copy
import hashlib
import json
import pathlib
import sys

def unique(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError("Duplicate receipt key")
        result[key] = value
    return result

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

repo, fixture = map(pathlib.Path, sys.argv[1:3])
mode, before, source_before, child_exit = sys.argv[3:]
child_exit = int(child_exit)
validator = repo / "plugins/sdd-quality-loop/scripts/check-workflow-state.ps1"
target = fixture / "reports/impl-review/workflow-state-integrity/attempt-1/round-2/precheck-result.json"
receipt_path = fixture / "pwsh-boundary-receipt.json"
anchor = '    $calibrationRelative = if ($Stage -eq "spec") {'
locations = [i + 1 for i, line in enumerate(validator.read_text(encoding="utf-8").splitlines()) if line == anchor]
assert len(locations) == 1, "Non-unique original boundary"
after = digest(target)
expected_exit = 1 if mode == "early-poison" else 0
expected_hits = 0 if mode == "early-poison" else 1
changed = mode != "control"
keys = {"schema", "mode", "hits", "validator", "validator_sha256", "line",
        "target", "receipt", "before", "after", "changed", "completed",
        "observer_ok", "child_exit"}

def valid(record):
    if not isinstance(record, dict) or set(record) != keys:
        return False
    if record["schema"] != "adr-pwsh-boundary/v1" or record["mode"] != mode:
        return False
    for key, expected in (("validator", validator), ("target", target), ("receipt", receipt_path)):
        if not isinstance(record[key], str) or pathlib.Path(record[key]).resolve() != expected.resolve():
            return False
    return (
        record["completed"] is True and record["observer_ok"] is True
        and type(record["child_exit"]) is int and record["child_exit"] == child_exit == expected_exit
        and type(record["hits"]) is int and record["hits"] == expected_hits
        and type(record["line"]) is int and record["line"] == locations[0]
        and record["validator_sha256"] == source_before == digest(validator)
        and record["before"] == before and record["after"] == after
        and record["changed"] is changed and (before != after) is changed
        and (not changed or target.read_bytes() == b"{")
    )

record = json.loads(receipt_path.read_text(encoding="utf-8"), object_pairs_hook=unique)
assert valid(record), "Invalid or incomplete observer receipt"
# Reject observer setup failure even when the expected child exit is 1.
for field, value in (("completed", False), ("observer_ok", False), ("child_exit", None)):
    negative = copy.deepcopy(record)
    negative[field] = value
    assert not valid(negative), "Incomplete observer was accepted"
print("ok: observer receipt and incomplete-receipt rejection: " + mode)
print(json.dumps(record, sort_keys=True))
