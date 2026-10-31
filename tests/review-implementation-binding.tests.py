"""Evaluator implementation-manifest binding, using disposable fixture ledgers only."""

import argparse
import importlib.util
import json
import pathlib
import shutil
import subprocess


def load_fixture(repo):
    path = repo / "tests/issue311-scratch-isolation.tests.py"
    spec = importlib.util.spec_from_file_location("issue311_fixture", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def exercise(fixture, repo, runtime, variant):
    actual_run = subprocess.run
    captured = []

    def intercept(command, *args, **kwargs):
        invocation = pathlib.Path(command[2] if runtime == "bash" else command[5])
        root = invocation.parent
        data = json.loads(invocation.read_text())
        manifest_path = root / data["implementation_manifest"]["path"]
        task_data = json.loads(manifest_path.read_text())
        report = root / "reports/implementation/f/T-001.md"
        if variant == "missing-inputs":
            task_data.pop("allowed_inputs")
        elif variant == "string-inputs":
            task_data["allowed_inputs"] = "specs/f/requirements.md"
        elif variant == "empty-inputs":
            task_data["allowed_inputs"] = []
        elif variant == "extra-input-key":
            task_data["allowed_inputs"][0]["extra"] = True
        elif variant == "null-input":
            task_data["allowed_inputs"] = [None]
        elif variant == "duplicate-inputs":
            task_data["allowed_inputs"].append(dict(task_data["allowed_inputs"][0]))
        elif variant == "bad-sha":
            task_data["allowed_inputs"][0]["sha256"] = "g" * 64
        elif variant == "trailing-newline-sha":
            task_data["allowed_inputs"][0]["sha256"] += "\n"
        elif variant == "underscore-root":
            task_data["allowed_inputs"][0]["path"] = "_root.md"
        elif variant == "hyphen-root":
            task_data["allowed_inputs"][0]["path"] = "-root.md"
        elif variant == "dot-root":
            task_data["allowed_inputs"][0]["path"] = ".github/workflows/test.yml"
        elif variant == "bad-path":
            task_data["allowed_inputs"][0]["path"] = "../requirements.md"
        elif variant == "newline-path":
            task_data["allowed_inputs"][0]["path"] = "foo\nbar"
        elif variant == "trailing-newline-path":
            task_data["allowed_inputs"][0]["path"] = "foo\n"
        elif variant == "tab-path":
            task_data["allowed_inputs"][0]["path"] = "foo\tbar"
        elif variant == "nul-path":
            task_data["allowed_inputs"][0]["path"] = "foo\x00bar"
        elif variant == "numeric-path":
            task_data["allowed_inputs"][0]["path"] = 123
        elif variant == "boolean-path":
            task_data["allowed_inputs"][0]["path"] = True
        elif variant == "wrong-task":
            task_data["task_id"] = "T-002"
        elif variant == "wrong-run":
            task_data["run_id"] = "other-worker-run"
        elif variant != "valid":
            raise ValueError(variant)
        old_hash = data["implementation_manifest"]["sha256"]
        fixture.write_json(manifest_path, task_data)
        new_hash = fixture.digest(manifest_path.read_bytes())
        report.write_text(report.read_text().replace(old_hash, new_hash))
        data["implementation_manifest"]["sha256"] = new_hash
        for entry in data["allowed_input_manifest"]:
            if entry["path"] == data["implementation_manifest"]["path"]:
                entry["sha256"] = new_hash
            elif entry["path"] == "reports/implementation/f/T-001.md":
                entry["sha256"] = fixture.digest(report.read_bytes())
        fixture.write_json(invocation, data)
        ledger = root / "reports/review-context/identity-ledger.json"
        before = ledger.read_bytes()
        flag = "--reserve" if runtime == "bash" else "-Reserve"
        command = command[:-1]  # fixture invokes reserve; test preflight separately
        preflight = actual_run(command, capture_output=True, text=True, timeout=40)
        preflight_unchanged = ledger.read_bytes() == before
        reserve = actual_run(command + [flag], capture_output=True, text=True, timeout=40)
        captured.append((preflight, reserve, preflight_unchanged, ledger.read_bytes() == before))
        raise StopIteration

    subprocess.run = intercept
    try:
        try:
            fixture.exercise(repo, runtime, "clean")
        except StopIteration:
            pass
    finally:
        subprocess.run = actual_run
    return captured[0]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=pathlib.Path, required=True)
    args = parser.parse_args()
    repo = args.repo.resolve()
    fixture = load_fixture(repo)
    failures = 0
    count = 0
    for runtime in ("bash", "pwsh"):
        if not shutil.which(runtime):
            raise SystemExit(f"required runtime missing: {runtime}")
        for variant in ("valid", "missing-inputs", "string-inputs", "empty-inputs",
                        "extra-input-key", "null-input", "duplicate-inputs", "bad-sha", "trailing-newline-sha", "bad-path", "underscore-root", "hyphen-root", "dot-root",
                        "newline-path", "trailing-newline-path",
                        "tab-path", "nul-path", "numeric-path", "boolean-path", "wrong-task",
                        "wrong-run"):
            pre, reserve, pre_unchanged, reserve_unchanged = exercise(fixture, repo, runtime, variant)
            valid = variant in ("valid", "dot-root")
            passed = (pre.returncode == 0) == valid and (reserve.returncode == 0) == valid
            passed = passed and pre_unchanged and (reserve_unchanged == (not valid))
            if not valid:
                if variant == "wrong-task":
                    expected = ("REVIEW_CONTEXT_IDENTITY: implementation manifest task/run/session/inputs is invalid"
                                if runtime == "bash" else
                                "REVIEW_CONTEXT_IDENTITY: implementation manifest task/run/session is invalid")
                elif variant == "wrong-run":
                    expected = "REVIEW_CONTEXT_IDENTITY: implementation report run/session does not match its manifest"
                elif runtime == "pwsh":
                    expected = "REVIEW_CONTEXT_IDENTITY: implementation manifest allowed_inputs is invalid"
                elif variant in ("bad-path", "underscore-root", "hyphen-root"):
                    expected = "REVIEW_CONTEXT_IDENTITY: implementation manifest input path is invalid"
                else:
                    expected = "REVIEW_CONTEXT_IDENTITY: implementation manifest task/run/session/inputs is invalid"
                passed = passed and all(expected in result.stderr for result in (pre, reserve))
            failures += not passed
            count += 1
            print(f"{'PASS' if passed else 'FAIL'} {runtime} {variant}: "
                  f"preflight={pre.returncode}, reserve={reserve.returncode}, "
                  f"preflight-ledger-unchanged={pre_unchanged}, reserve-ledger-unchanged={reserve_unchanged}")
            if not passed:
                print("PREFLIGHT", pre.stdout, pre.stderr)
                print("RESERVE", reserve.stdout, reserve.stderr)
    print(f"PASS: {count - failures}; FAIL: {failures}")
    raise SystemExit(1 if failures else 0)


if __name__ == "__main__":
    main()
