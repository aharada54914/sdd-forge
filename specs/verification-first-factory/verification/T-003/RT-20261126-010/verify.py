"""Replay T-003 on the tested tree and print its RT-010 evidence as JSON."""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[4]
FITNESS = "tests/self-fitness.test.mjs"
SOURCE = "f809c535932fb1d70be09d9327404d6b70b69c38"
MANIFEST = EVIDENCE / "task-input-manifest.json"
PATTERN = "detects Copilot configuration drift at the "
MISSED = {"Bash existence path", "PowerShell guard presence reference", "PowerShell existence reference"}


def run(*args, expected=0):
    result = subprocess.run(["rtk", "proxy", *args], cwd=ROOT, capture_output=True)
    if result.returncode != expected:
        raise RuntimeError((args, result.returncode, result.stdout.decode(), result.stderr.decode()))
    return result


def digest(data):
    return hashlib.sha256(data).hexdigest()


def sites(tap):
    rows = re.findall(r"^    (ok|not ok) \d+ - " + PATTERN + r"([^\n]+)$", tap.decode(), re.M)
    assert len(rows) == 6 and len({site for _, site in rows}) == 6
    return {site: status for status, site in rows}


def before_fix():
    baseline = run("git", "show", f"{SOURCE}^:{FITNESS}").stdout.decode()
    checks = (ROOT / FITNESS).read_text()
    start, end = "function checkHostParity(", "function hasPinnedReleaseLine("
    combined = checks[:checks.index(start)] + baseline[baseline.index(start):baseline.index(end)] + checks[checks.index(end):]
    with tempfile.NamedTemporaryFile(dir=ROOT / "tests", suffix=".mjs", mode="w") as fixture:
        fixture.write(combined)
        fixture.flush()
        red = run("node", "--test", "--test-reporter=tap", "--test-name-pattern=" + PATTERN, fixture.name, expected=1)
    results = sites(red.stdout)
    assert {site for site, status in results.items() if status == "not ok"} == MISSED
    return results


def inventory():
    catalog = json.loads((ROOT / "tests/verification-catalog.json").read_bytes())["suites"]
    missing = [s["path"] for s in catalog if not (ROOT / s["path"]).is_file()]
    parity = (EVIDENCE.parent / "retirement-parity.md").read_text()
    rows = re.findall(r"^\| [14] \| `([^`]+)` \| `([0-9a-f]{40})` \|$", parity, re.M)
    changed = [path for path, blob in rows if run("git", "hash-object", "--", path).stdout.decode().strip() != blob]
    approved = json.loads((ROOT / "sdd/approved-test-retirements.json").read_bytes())["retirements"]
    assert len(catalog) == 349 and not missing
    assert len(rows) == len({path for path, _ in rows}) == 36 and not changed and not approved
    return {"catalog_entries": len(catalog), "missing_files": missing, "retained_candidate_blobs": len(rows),
            "changed_candidate_blobs": changed, "approved_retirements": approved}


def main():
    m = json.loads(MANIFEST.read_bytes())
    assert run("git", "show", f"{SOURCE}:{FITNESS}").stdout == (ROOT / FITNESS).read_bytes()
    red = before_fix()
    commands = []
    green = {}
    for args in [
        ["bash", "plugins/sdd-implementation/scripts/validate-task-input-manifest.sh", "--manifest",
         str(MANIFEST.relative_to(ROOT)), "--snapshot-root", ".", "--expected-task", "T-003"],
        ["node", "--test", "--test-reporter=tap", FITNESS],
        ["python3", "tests/verification-catalog.tests.py"],
        ["python3", "tests/verification.py", "--profile", "local-posix", "--list"],
        ["node", "tests/verification-catalog-status.mjs"],
    ]:
        result = run(*args)
        if args[-1] == FITNESS:
            green = sites(result.stdout)
            assert red.keys() == green.keys() and all(v == "ok" for v in green.values())
            assert b"# pass 16\n" in result.stdout
        if args[-1] == "tests/verification-catalog.tests.py":
            assert b"Ran 23 tests" in result.stderr and result.stderr.strip().endswith(b"OK")
        if args[-1] == "--list":
            assert len(result.stdout.splitlines()) == 195
        if args[-1] == "tests/verification-catalog-status.mjs":
            assert result.stdout == (ROOT / "docs/operations/verification-catalog-status.md").read_bytes()
        commands.append({"argv": args, "exit_code": result.returncode, "stdout_sha256": digest(result.stdout),
                         "stdout": result.stdout.decode(), "stderr": result.stderr.decode()})
    print(json.dumps({"revision": SOURCE, "red_implementation_revision": run("git", "rev-parse", SOURCE + "^").stdout.decode().strip(),
                      "run_id": m["run_id"], "session_id": m["session_id"], "agent_instance_id": m["agent_instance_id"],
                      "input_manifest_sha256": digest(MANIFEST.read_bytes()), "runner_sha256": digest(Path(__file__).read_bytes()),
                      "before_fix": red, "after_fix": green, "commands": commands, "inventory": inventory()},
                     indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
