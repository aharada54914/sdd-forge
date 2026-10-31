#!/usr/bin/env python3
"""Exercise the pinned pre-Concept-Test validator in a disposable release tree."""
import hashlib
import hmac
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

BASE = "badbb7aa5d16114be542c33018967c58770d1a41"
ROOT = Path(__file__).resolve().parents[4]


def run(args, cwd, env=None):
    result = subprocess.run(args, cwd=cwd, env=env, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(f"{args[0]} exited {result.returncode}: {result.stderr}")
    return result.stdout


def main():
    with tempfile.TemporaryDirectory(prefix="sdd290-rollback-") as directory:
        work = Path(directory)
        archive = work / "baseline.tar"
        run(["git", "archive", "--format=tar", f"--output={archive}", BASE,
             "contracts", "plugins/sdd-quality-loop/scripts"], ROOT)
        baseline = work / "release"
        baseline.mkdir()
        with tarfile.open(archive) as bundle:
            bundle.extractall(baseline, filter="data")
        scripts = baseline / "plugins/sdd-quality-loop/scripts"
        validator = scripts / "validate-approval-sidecar.py"
        canonicalizer = scripts / "canonicalize-sdd-yaml.py"
        print(f"baseline_commit={BASE}")
        print(f"validator_sha256={hashlib.sha256(validator.read_bytes()).hexdigest()}")
        registry = work / "registry.yaml"
        registry.write_text("schema: sdd-approver-registry/v1\napprovers:\n"
                            "  - id: fixture-owner\n    name: Fixture Owner\n")
        env = dict(os.environ, SDD_CONTEXT_KEY="synthetic-rollback-test-key")

        def validate(label, content, sidecar, expected):
            result = subprocess.run(
                [sys.executable, str(validator), "--content", str(content),
                 "--sidecar", str(sidecar), "--approver-registry", str(registry)],
                cwd=work, env=env, text=True, capture_output=True)
            if expected == "VALID":
                assert result.returncode == 0 and result.stdout.strip() == expected, result.stderr
            else:
                assert result.returncode != 0 and expected in result.stderr, (result.returncode, result.stderr)
            print(f"PASS: {label}: {expected}")

        def sign(content, schema):
            sidecar = work / "approval.json"
            digest = run([sys.executable, str(canonicalizer), str(content),
                          "--input-format", "json" if content.suffix == ".json" else "yaml",
                          "--hash-only"], work).strip()
            obj = {"schema": schema, "context_sha256": digest,
                   "primary_approval": {"status": "Approved", "approver": "fixture-owner",
                                        "approved_at": "2026-01-01T00:00:00Z"},
                   "second_approval": None, "effective_at": None,
                   "predecessor_context_sha256": None, "weakening_verdict": None,
                   "approval_epoch": 1}
            sidecar.write_text(json.dumps(obj))
            canonical = run([sys.executable, str(canonicalizer), str(sidecar),
                             "--input-format", "json"], work).encode()
            obj["hmac"] = hmac.new(env["SDD_CONTEXT_KEY"].encode(), canonical, hashlib.sha256).hexdigest()
            sidecar.write_text(json.dumps(obj))
            return sidecar

        for kind, data in (
            ("project-context", "schema: sdd-project-context/v1\nworkflow:\n"
             "  spec_profile: full\n  artifact_layout: lite-three-file\n  capability_enforcement: required\n"),
            ("provider-bindings", "schema: sdd-provider-bindings/v1\nbindings: []\n"),
        ):
            content = work / f"{kind}.yaml"
            content.write_text(data)
            validate(kind, content, sign(content, f"sdd-{kind}-approval/v1"), "VALID")

        concept = work / "concept-test.json"
        concept.write_text(json.dumps({"schema": "sdd-concept-test/v1", "feature": "fixture",
            "proposal": "FITS_EXISTING_CONCEPTS", "rationale": "fixture", "relation": "same",
            "decision": None, "inputs": [{"path": str(registry), "sha256": hashlib.sha256(registry.read_bytes()).hexdigest()}]}))
        validate("unsigned concept", concept, work / "missing.json", "SIDECAR_UNREADABLE")
        validate("signed concept route disabled", concept, sign(concept, "sdd-concept-test-approval/v1"), "SIDECAR_SCHEMA_VIOLATION")
        concept = work / "concept-test.yaml"
        concept.write_text("schema: sdd-concept-test/v1\nfeature: fixture\n")
        for kind in ("project-context", "provider-bindings"):
            validate(f"concept cannot use legacy {kind} route", concept,
                     sign(concept, f"sdd-{kind}-approval/v1"), "CONTENT_SCHEMA_VIOLATION")
        print("PASS: 6; FAIL: 0. Disposable rollback only; production unchanged.")


if __name__ == "__main__":
    main()
