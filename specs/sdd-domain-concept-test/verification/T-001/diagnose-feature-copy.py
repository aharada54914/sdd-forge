"""Disposable, synthetic-key check of cross-feature Concept Test reuse."""

import hashlib
import hmac
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[4]
SCRIPTS = ROOT / "plugins/sdd-quality-loop/scripts"
CANON = SCRIPTS / "canonicalize-sdd-yaml.py"
VALIDATOR = SCRIPTS / "validate-approval-sidecar.py"
sys.path.insert(0, str(SCRIPTS))
from concept_test_render import render_concept_test_md  # noqa: E402


def canonicalize(path, *args):
    return subprocess.run(
        [sys.executable, str(CANON), str(path), "--input-format", "json", *args],
        check=True, capture_output=True,
    ).stdout


with tempfile.TemporaryDirectory(prefix="sdd290-feature-copy-") as scratch:
    base = Path(scratch)
    source = base / "specs/feature-a"
    target = base / "specs/feature-b"
    source.mkdir(parents=True)
    evidence_input = base / "input.txt"
    evidence_input.write_text("synthetic input\n", encoding="utf-8")
    concept = {
        "schema": "sdd-concept-test/v1",
        "feature": "feature-a",
        "proposal": "NEW_CONCEPT_CANDIDATE",
        "rationale": "Synthetic cross-feature diagnosis",
        "relation": "different",
        "decision": "proceed",
        "inputs": [{"path": str(evidence_input), "sha256": hashlib.sha256(evidence_input.read_bytes()).hexdigest()}],
    }
    content = source / "concept-test.json"
    content.write_text(json.dumps(concept), encoding="utf-8")
    (source / "concept-test.md").write_bytes(render_concept_test_md(concept))
    sidecar = {
        "schema": "sdd-concept-test-approval/v1",
        "context_sha256": canonicalize(content, "--hash-only").decode().strip(),
        "primary_approval": {"status": "Approved", "approver": "alice", "approved_at": "2026-01-01T00:00:00Z"},
        "second_approval": None,
        "effective_at": None,
        "predecessor_context_sha256": None,
        "weakening_verdict": None,
        "approval_epoch": 1,
    }
    preimage = base / "preimage.json"
    preimage.write_text(json.dumps(sidecar), encoding="utf-8")
    synthetic_key = b"test-context-key-epic189-t006"
    sidecar["hmac"] = hmac.new(synthetic_key, canonicalize(preimage), hashlib.sha256).hexdigest()
    (source / "concept-test.approval.json").write_text(json.dumps(sidecar), encoding="utf-8")
    registry = base / "approver-registry.yaml"
    registry.write_text("schema: sdd-approver-registry/v1\napprovers:\n  - id: alice\n    name: Alice Example\n", encoding="utf-8")
    shutil.copytree(source, target)
    env = dict(os.environ, SDD_CONTEXT_KEY=synthetic_key.decode())
    for label, directory in (("source A", source), ("copied to B", target)):
        result = subprocess.run(
            [sys.executable, str(VALIDATOR), "--content", str(directory / "concept-test.json"),
             "--sidecar", str(directory / "concept-test.approval.json"),
             "--approver-registry", str(registry)],
            env=env, cwd=ROOT, capture_output=True, text=True,
        )
        print(f"{label}: exit={result.returncode} stdout={result.stdout.strip()!r} stderr={result.stderr.strip()!r}")
