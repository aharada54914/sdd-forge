"""Exercise actual validators on disposable fixture ledgers, never live identities."""
import argparse
import hashlib
import json
import shutil
from pathlib import Path
import subprocess
import tempfile


def available_runtimes():
    return ("bash", "pwsh") if shutil.which("pwsh") else ("bash",)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def put_json(path, value):
    path.write_text(json.dumps(value) + "\n", encoding="utf-8")


def link_fixture(path, root, file_kind):
    alias = root / "investigation-alias.md"
    if file_kind == "hardlink":
        alias.hardlink_to(path)
    elif file_kind == "symlink":
        path.rename(alias)
        path.symlink_to(alias)


def probe(repo, runtime, stage, suffix, case, mode="reservation", file_kind="regular", verify_runtime=None):
    with tempfile.TemporaryDirectory(prefix="sdd-288-reservation-") as temporary:
        root = Path(temporary).resolve()
        ledger = root / "reports/review-context/identity-ledger.json"
        ledger.parent.mkdir(parents=True)
        spec = root / "specs/rcb"
        spec.mkdir(parents=True)
        requirements = spec / "requirements.md"
        requirements.write_text("fixture requirements\n", encoding="utf-8")
        prior = digest(b"1|spec|spec-reviewer-a|fixture-1|session-1|")
        record = dict(sequence=1, stage="spec", role="spec-reviewer-a",
                      run_id="fixture-1", host_session_id="session-1",
                      previous_record_sha256="", record_sha256=prior)
        put_json(ledger, dict(schema="review-identity-ledger/v1", records=[record]))
        role = f"{stage}-reviewer-{suffix}"
        document = dict(schema="review-context-invocation/v2", input_mode="file-manifest",
                        fallback_mode="none", read_only=True, stage=stage, role=role,
                        feature="rcb", run_id="fixture-2", host_session_id="session-2",
                        sequence=2, identity_ledger_path="reports/review-context/identity-ledger.json",
                        identity_ledger_sha256=digest(ledger.read_bytes()),
                        previous_record_sha256=prior,
                        allowed_input_manifest=[dict(path="specs/rcb/requirements.md",
                                                     sha256=digest(requirements.read_bytes()))])
        investigation = spec / "investigation.md"
        if case not in ("historical", "late-added"):
            investigation.write_text("fixture investigation\n", encoding="utf-8")
            link_fixture(investigation, root, file_kind)
        if case in ("declared", "bad-hash", "late-removed", "late-hash", "reserved-unchanged"):
            document["allowed_input_manifest"].append(dict(
                path="specs/rcb/investigation.md",
                sha256="0" * 64 if case == "bad-hash" else digest(investigation.read_bytes())))
        manifest = root / "manifest.json"
        put_json(manifest, document)
        base = repo / "plugins/sdd-quality-loop/scripts/validate-review-context-set"
        if runtime == "bash":
            command = ["bash", str(base.with_suffix(".sh")), str(manifest), str(root)]
            reserve = "--reserve"
        else:
            command = ["pwsh", "-NoLogo", "-NoProfile", "-File", str(base.with_suffix(".ps1")),
                       "-Manifest", str(manifest), "-RepositoryRoot", str(root)]
            reserve = "-Reserve"
        verification_command = command
        if verify_runtime is not None and verify_runtime != runtime:
            verification_command = (["bash", str(base.with_suffix(".sh")), str(manifest), str(root)]
                                    if verify_runtime == "bash" else
                                    ["pwsh", "-NoLogo", "-NoProfile", "-File", str(base.with_suffix(".ps1")),
                                     "-Manifest", str(manifest), "-RepositoryRoot", str(root)])
        before = ledger.read_bytes()
        arguments = command + ([reserve] if mode == "reservation" else [])
        result = subprocess.run(arguments, capture_output=True, text=True, timeout=60)
        if case in ("historical", "late-added"):
            if result.returncode:
                raise RuntimeError("baseline reservation failed: " + result.stdout + result.stderr)
            investigation.write_text("added after reservation\n", encoding="utf-8")
            link_fixture(investigation, root, file_kind)
            if case == "late-added":
                document["allowed_input_manifest"].append(dict(
                    path="specs/rcb/investigation.md", sha256=digest(investigation.read_bytes())))
                put_json(manifest, document)
            before = ledger.read_bytes()
            result = subprocess.run(verification_command, capture_output=True, text=True, timeout=60)
        elif case in ("late-removed", "late-hash"):
            if result.returncode:
                raise RuntimeError("baseline reservation failed: " + result.stdout + result.stderr)
            if case == "late-removed":
                document["allowed_input_manifest"].pop()
            else:
                investigation.write_text("changed after reservation\n", encoding="utf-8")
                document["allowed_input_manifest"][-1]["sha256"] = digest(investigation.read_bytes())
            put_json(manifest, document)
            before = ledger.read_bytes()
            result = subprocess.run(verification_command, capture_output=True, text=True, timeout=60)
        elif case == "reserved-unchanged":
            if result.returncode:
                raise RuntimeError("baseline reservation failed: " + result.stdout + result.stderr)
            before = ledger.read_bytes()
            result = subprocess.run(verification_command, capture_output=True, text=True, timeout=60)
        rejected = case in ("declared", "bad-hash") if stage == "task" else case in ("omitted", "bad-hash")
        if case in ("late-added", "late-removed", "late-hash"):
            rejected = True
        if file_kind == "symlink" and case in ("declared", "bad-hash"):
            rejected = True
        expected = 1 if rejected else 0
        unchanged = ledger.read_bytes() == before
        valid = result.returncode == expected
        if expected == 1:
            valid = valid and unchanged
            diagnostic = ("reserved input" if case in ("late-added", "late-removed", "late-hash") else
                          "role-unlisted" if stage == "task" else
                          "REVIEW_CONTEXT_PATH" if file_kind == "symlink" and case in ("declared", "bad-hash") else
                          "REVIEW_CONTEXT_HASH" if case == "bad-hash" else "investigation")
            valid = valid and diagnostic in result.stdout + result.stderr
        elif case in ("historical", "reserved-unchanged") or mode == "preflight":
            valid = valid and unchanged
        else:
            records = json.loads(ledger.read_text(encoding="utf-8"))["records"]
            valid = valid and not unchanged and len(records) == 2 and records[-1]["role"] == role
        print(json.dumps(dict(runtime=runtime, verify_runtime=verify_runtime or runtime, stage=stage, role=role, case=case, mode=mode, file_kind=file_kind, expected_exit=expected,
                              actual_exit=result.returncode, ledger_unchanged=unchanged,
                              passed=valid, stdout=result.stdout.strip(), stderr=result.stderr.strip())), flush=True)
        return valid


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, required=True)
    parser.add_argument("--mode", choices=("reservation", "preflight", "all"), default="all")
    parser.add_argument("--file-kind", choices=("regular", "hardlink", "symlink"), default="regular")
    parser.add_argument("--cross-runtime", action="store_true",
                        help="Also verify spec/impl reservations using the other available runtime")
    args = parser.parse_args()
    modes = ("reservation", "preflight") if args.mode == "all" else (args.mode,)
    runtimes = available_runtimes()
    if "pwsh" not in runtimes:
        print("SKIP: PowerShell cases (pwsh unavailable); Bash cases remain required", flush=True)
    results = [probe(args.repo.resolve(), runtime, stage, suffix, case, mode, args.file_kind)
               for mode in modes for runtime in runtimes for stage in ("spec", "impl", "task")
               for suffix in ("a", "b")
               for case in (("omitted", "declared", "bad-hash", "historical") +
                            (("late-added", "late-removed", "late-hash", "reserved-unchanged") if stage in ("spec", "impl") and args.file_kind == "regular" else ())
                            if mode == "reservation" else ("omitted", "declared", "bad-hash"))]
    if args.cross_runtime:
        if "pwsh" not in runtimes:
            print("SKIP: cross-runtime reservations (pwsh unavailable)", flush=True)
        else:
            results.extend(probe(args.repo.resolve(), runtime, stage, suffix, case,
                                 verify_runtime="pwsh" if runtime == "bash" else "bash")
                           for runtime in runtimes for stage in ("spec", "impl") for suffix in ("a", "b")
                           for case in ("historical", "reserved-unchanged", "late-added", "late-removed", "late-hash"))
    print(f"PASS: {sum(results)}; FAIL: {len(results) - sum(results)}")
    raise SystemExit(0 if all(results) else 1)
