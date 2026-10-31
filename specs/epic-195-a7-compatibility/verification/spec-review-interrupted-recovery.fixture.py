#!/usr/bin/env python3
"""Post-apply, isolated A7 interrupted-review recovery regression.

Run only after the protected prechecks have been applied by the human owner.
This copies evidence into a temporary repository; it never writes source evidence.
"""

from __future__ import annotations

import hashlib
import json
import pathlib
import shutil
import subprocess
import tempfile


ROOT = pathlib.Path(__file__).resolve().parents[3]
FEATURE = "epic-195-a7-compatibility"
SCRIPT = "plugins/sdd-review-loop/scripts/spec-review-precheck"
CONTEXT = f"reports/review-context/{FEATURE}-spec-a8r1"
TERMINAL = f"reports/spec-review/{FEATURE}/attempt-7/round-2"
OLD = f"reports/spec-review/{FEATURE}/attempt-8/round-1"
NEW = f"reports/spec-review/{FEATURE}/attempt-9/round-1"


def digest(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fixture(path: pathlib.Path) -> pathlib.Path:
    for rel in ("plugins/sdd-review-loop", "plugins/sdd-quality-loop"):
        shutil.copytree(ROOT / rel, path / rel)
    # Reconstruct the specific historical interruption, not today's full report
    # tree: real attempt-9 (or later) is deliberately not a test destination.
    # Keep the ledger byte-for-byte, including valid later reservations; the
    # persisted invocation is verified against its historical record, not tip.
    inputs = [f"specs/{FEATURE}/{name}" for name in
              ("requirements.md", "acceptance-tests.md", "investigation.md")]
    inputs += [f"{TERMINAL}/{name}" for name in
               ("spec-review-contract.json", "precheck-result.json",
                "integrated-summary.json", "integrated-verdict.json",
                "reviewer-a.json", "reviewer-b.json")]
    inputs += [f"{OLD}/precheck-result.json", f"{OLD}/reviewer-a-host-allocation.json",
               f"{OLD}/launch-blocker-note.md",
               CONTEXT + "-a-invocation.json", "reports/review-context/identity-ledger.json"]
    for rel in inputs:
        destination = path / rel
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, destination)
    if (path / NEW).exists():
        raise AssertionError("fixture imported the live recovery destination")
    return path


def run(root: pathlib.Path, runtime: str, *args: str) -> subprocess.CompletedProcess[str]:
    script = root / (SCRIPT + (".sh" if runtime == "bash" else ".ps1"))
    command = (["bash", str(script)] if runtime == "bash"
               else ["pwsh", "-NoProfile", "-File", str(script)])
    options = list(args)
    if runtime == "pwsh":
        options = [{"--reset": "-Reset", "--recover-interrupted": "-RecoverInterrupted"}.get(arg, arg)
                   for arg in options]
    return subprocess.run(command + [FEATURE, *options], cwd=root, text=True,
                          capture_output=True, timeout=90)


def require(result: subprocess.CompletedProcess[str], ok: bool, label: str) -> None:
    if (result.returncode == 0) != ok:
        raise AssertionError(f"{label}: exit={result.returncode}; "
                             f"stdout={result.stdout[-500:]!r}; stderr={result.stderr[-500:]!r}")


def mutate(root: pathlib.Path, case: str) -> None:
    if case in ("foreign-root", "mixed-root", "external-path", "manifest-hash"):
        prior = root / TERMINAL
        for name in ("spec-review-contract.json", "reviewer-a.json", "reviewer-b.json"):
            path = prior / name
            data = json.loads(path.read_text())
            manifests = ([r["allowed_input_manifest"] for r in data["reviewers"]]
                         if "reviewers" in data else [data["allowed_input_manifest"]])
            if case in ("foreign-root", "mixed-root"):
                for manifest in manifests:
                    for entry in manifest:
                        entry["path"] = "/opt/fixture-checkout/sdd-forge/" + entry["path"]
            if name == "spec-review-contract.json":
                entry = manifests[0][0]
                if case == "mixed-root":
                    entry["path"] = entry["path"].replace("/opt/fixture-checkout/", "/opt/other-checkout/")
                elif case == "external-path":
                    entry["path"] = "/outside/unrecognized/calibration.md"
                elif case == "manifest-hash":
                    entry["sha256"] = "0" * 64
            path.write_text(json.dumps(data))
    elif case == "missing-invocation":
        (root / (CONTEXT + "-a-invocation.json")).unlink()
    elif case == "altered-invocation":
        path = root / (CONTEXT + "-a-invocation.json")
        data = json.loads(path.read_text())
        for item in data["allowed_input_manifest"]:
            if item["path"] == f"{OLD}/precheck-result.json":
                item["sha256"] = "0" * 64
                break
        else:
            raise AssertionError("fixture invocation lacks prior precheck")
        path.write_text(json.dumps(data))
    elif case == "missing-reservation":
        path = root / "reports/review-context/identity-ledger.json"
        data = json.loads(path.read_text())
        data["records"] = [record for record in data["records"] if record["sequence"] != 1191]
        path.write_text(json.dumps(data))
    elif case == "b-invocation":
        shutil.copy2(root / (CONTEXT + "-a-invocation.json"),
                     root / (CONTEXT + "-b-invocation.json"))
    elif case == "reviewer-output":
        (root / OLD / "reviewer-a.json").write_text("{}\n")
    elif case == "changed-allocation":
        path = root / OLD / "reviewer-a-host-allocation.json"
        data = json.loads(path.read_text())
        data["host_id"] = "bad00000"
        path.write_text(json.dumps(data))
    elif case == "nonterminal-predecessor":
        rounds = sorted((root / f"reports/spec-review/{FEATURE}/attempt-7").glob("round-*/spec-review-contract.json"))
        path = rounds[-1]
        data = json.loads(path.read_text())
        data["verdict"] = "NEEDS_WORK"
        path.write_text(json.dumps(data))
    elif case == "occupied-destination":
        (root / NEW).mkdir(parents=True)
    elif case == "later-ledger-record":
        path = root / "reports/review-context/identity-ledger.json"
        data = json.loads(path.read_text())
        tip = data["records"][-1]
        sequence = tip["sequence"] + 1
        previous = tip["record_sha256"]
        stage, role, run_id, session = "spec", "spec-reviewer-b", "fixture1", "fixture-session-1"
        fields = f"{sequence}|{stage}|{role}|{run_id}|{session}|{previous}"
        data["records"].append({"sequence": sequence, "stage": stage, "role": role,
                                "run_id": run_id, "host_session_id": session,
                                "previous_record_sha256": previous,
                                "record_sha256": hashlib.sha256(fields.encode()).hexdigest()})
        path.write_text(json.dumps(data))
    else:
        raise AssertionError(case)


def main() -> None:
    if "recover-interrupted" not in (ROOT / (SCRIPT + ".sh")).read_text() or \
       "RecoverInterrupted" not in (ROOT / (SCRIPT + ".ps1")).read_text():
        raise SystemExit("NOT RUN: human-authorized protected patch is not applied")
    for runtime in ("bash", "pwsh"):
        with tempfile.TemporaryDirectory(prefix=f"a7-recovery-{runtime}-") as temp:
            root = fixture(pathlib.Path(temp) / "repo")
            old = {str(p.relative_to(root)): digest(p) for p in (root / OLD).iterdir() if p.is_file()}
            inv = digest(root / (CONTEXT + "-a-invocation.json"))
            ledger = digest(root / "reports/review-context/identity-ledger.json")
            require(run(root, runtime, "9", "1", "--reset", "--recover-interrupted"), True,
                    f"{runtime} recovery")
            if not (root / NEW / "precheck-result.json").is_file():
                raise AssertionError(f"{runtime}: no fresh precheck")
            for rel, old_hash in old.items():
                if digest(root / rel) != old_hash:
                    raise AssertionError(f"{runtime}: prior evidence changed: {rel}")
            if digest(root / (CONTEXT + "-a-invocation.json")) != inv or \
               digest(root / "reports/review-context/identity-ledger.json") != ledger:
                raise AssertionError(f"{runtime}: reservation changed")
            require(run(root, runtime, "9", "1", "--reset", "--recover-interrupted"), False,
                    f"{runtime} replay")
            print(f"PASS {runtime} recovery + immutability + replay")
        for case in ("missing-invocation", "altered-invocation", "missing-reservation",
                     "b-invocation", "reviewer-output", "changed-allocation",
                     "nonterminal-predecessor", "occupied-destination",
                     "mixed-root", "external-path", "manifest-hash"):
            with tempfile.TemporaryDirectory(prefix=f"a7-{runtime}-{case}-") as temp:
                root = fixture(pathlib.Path(temp) / "repo")
                mutate(root, case)
                require(run(root, runtime, "9", "1", "--reset", "--recover-interrupted"),
                        False, f"{runtime} {case}")
                if case != "occupied-destination" and (root / NEW).exists():
                    raise AssertionError(f"{runtime} {case}: wrote destination on rejection")
                print(f"PASS {runtime} rejects {case}")
        with tempfile.TemporaryDirectory(prefix=f"a7-{runtime}-foreign-root-") as temp:
            root = fixture(pathlib.Path(temp) / "repo")
            mutate(root, "foreign-root")
            require(run(root, runtime, "9", "1", "--reset", "--recover-interrupted"),
                    True, f"{runtime} foreign historical root")
            print(f"PASS {runtime} foreign historical root")
        with tempfile.TemporaryDirectory(prefix=f"a7-{runtime}-later-") as temp:
            root = fixture(pathlib.Path(temp) / "repo")
            mutate(root, "later-ledger-record")
            require(run(root, runtime, "9", "1", "--reset", "--recover-interrupted"),
                    True, f"{runtime} later unrelated ledger record")
            print(f"PASS {runtime} later unrelated ledger record")
        with tempfile.TemporaryDirectory(prefix=f"a7-{runtime}-arguments-") as temp:
            root = fixture(pathlib.Path(temp) / "repo")
            for args in (("9", "1", "--recover-interrupted"),
                         ("9", "2", "--reset", "--recover-interrupted"),
                         ("10", "1", "--reset", "--recover-interrupted")):
                require(run(root, runtime, *args), False, f"{runtime} bad arguments {args}")
            if (root / NEW).exists():
                raise AssertionError(f"{runtime}: bad arguments wrote destination")
            print(f"PASS {runtime} rejects wrong arguments")


if __name__ == "__main__":
    main()
