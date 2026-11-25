"""Replay RT-005 and T-003 checks from the repository root. Print a JSON receipt."""
import hashlib
import json
import re
import subprocess
import tempfile
from pathlib import Path

EVIDENCE = Path(__file__).resolve().parent
ROOT = EVIDENCE.parents[4]
FITNESS = Path("tests/self-fitness.test.mjs")
BASELINE = "0e5b0952a54279fb98cc7885943070a5ed8378e5^"
TARGETS = [
    "hooks/claude-hooks.json 0", "hooks/codex-hooks.json command",
    "hooks/codex-hooks.json command_windows", "hooks/copilot-hooks.json bash",
    "hooks/copilot-hooks.json powershell", "hooks.json command",
    "gemini/hooks/hooks.json command",
]


def run(*args):
    return subprocess.run(["rtk", "proxy", *args], cwd=ROOT, capture_output=True)


def result(*args):
    completed = run(*args)
    completed.check_returncode()
    return completed.stdout


def directory_controls():
    # Run the shipped assertion once per command, so a first failure cannot mask the others.
    current = (ROOT / FITNESS).read_text()
    old = result("git", "show", f"{BASELINE}:{FITNESS}").decode()
    start, end = "function checkHostParity(", "function hasPinnedReleaseLine("
    red = current[:current.index(start)] + old[old.index(start):old.index(end)] + current[current.index(end):]
    selector = "of cases) {"
    assert current.count(selector) == 1
    rows = []
    for index, target in enumerate(TARGETS):
        row = {"target": target}
        for name, source in [("red", red), ("green", current)]:
            case = source.replace(selector, f"of cases.slice({index}, {index + 1})) {{")
            with tempfile.NamedTemporaryFile(dir=ROOT / "tests", suffix=".mjs", mode="w") as temporary:
                temporary.write(case)
                temporary.flush()
                cmd = run("node", "--test", "--test-reporter=tap",
                          "--test-name-pattern=directory-only", temporary.name)
            stdout = cmd.stdout.decode()
            if name == "red":
                assert cmd.returncode == 1 and f"error: '{target}'" in stdout, stdout
            else:
                assert cmd.returncode == 0 and "ok 1 - rejects a directory-only change" in stdout, stdout
            row[name] = {"exit_code": cmd.returncode, "assertion": target,
                         "expected_detection": name == "green"}
        rows.append(row)
    return rows


def catalog_and_candidates():
    catalog = json.loads((ROOT / "tests/verification-catalog.json").read_text())["suites"]
    missing = [s["path"] for s in catalog if not (ROOT / s["path"]).is_file()]
    parity = (EVIDENCE.parent / "retirement-parity.md").read_text()
    candidates = re.findall(r"^\| ([14]) \| `([^`]+)` \| `([0-9a-f]{40})` \|$", parity, re.M)
    changed = []
    for _, path, blob in candidates:
        if result("git", "hash-object", "--", path).decode().strip() != blob:
            changed.append(path)
    approved = json.loads((ROOT / "sdd/approved-test-retirements.json").read_text())["retirements"]
    assert (len(catalog), missing, len({p for _, p, _ in candidates}), changed, approved) == (348, [], 36, [], [])
    return {"catalog_entries": len(catalog), "missing_files": missing,
            "candidate_count": len(candidates), "changed_candidate_blobs": changed,
            "approved_retirements": approved, "retired_candidates": 0}


def main():
    manifest_path = EVIDENCE / "task-input-manifest.json"
    manifest = json.loads(manifest_path.read_bytes())
    controls = directory_controls()
    commands = []
    for argv, expected in [
        (["node", "--test", "--test-reporter=tap", str(FITNESS)], "# pass 10"),
        (["python3", "tests/verification-catalog.tests.py"], "Ran 23 tests"),
        (["python3", "tests/verification.py", "--profile", "local-posix", "--list"], None),
        (["node", "tests/verification-catalog-status.mjs"], None),
    ]:
        raw = run(*argv)
        raw.check_returncode()
        output = raw.stdout + raw.stderr
        if expected:
            assert expected.encode() in output, output
        if "--list" in argv:
            assert len(raw.stdout.splitlines()) == 195
        if argv[-1].endswith("catalog-status.mjs"):
            assert raw.stdout == (ROOT / "docs/operations/verification-catalog-status.md").read_bytes()
        commands.append({"argv": argv, "exit_code": raw.returncode,
                         "stdout_sha256": hashlib.sha256(raw.stdout).hexdigest(),
                         "output": output.decode()})
    receipt = {"revision": result("git", "rev-parse", "HEAD").decode().strip(),
               "run_id": manifest["run_id"], "session_id": manifest["session_id"],
               "agent_instance_id": manifest["agent_instance_id"],
               "input_manifest_sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
               "runner_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
               "red_implementation_revision": result("git", "rev-parse", BASELINE).decode().strip(),
               "directory_controls": controls, "commands": commands,
               "inventory": catalog_and_candidates()}
    print(json.dumps(receipt, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
