#!/usr/bin/env python3
"""Candidate-only AC-004 oracle regression; never launches a CLI or edits fixtures."""

import os
from pathlib import Path
import subprocess


root = Path(__file__).resolve().parents[4]
driver = (root / "tests/cross-runtime-handoff.tests.sh").read_text()
assert "printf 'COPILOT-CONSUMED:%s' \"$nonce2\"" in driver
candidate_root = root / "specs/epic-196-a8-integration/verification/T-001/candidate"
candidate_sh = (candidate_root / "tests/cross-runtime-handoff.tests.sh").read_text()
candidate_ps1 = (candidate_root / "tests/cross-runtime-handoff.tests.ps1").read_text()
assert "printf 'COPILOT-CONSUMED:%s:%s' \"$nonce1\" \"$nonce2\"" in candidate_sh
assert "'COPILOT-CONSUMED:' + $nonce1 + ':' + $nonce2" in candidate_ps1


def oracle_hash(source: str, first: str, second: str) -> str:
    lines = [line for line in source.splitlines() if line.startswith("expected_output_sha=$(")]
    assert len(lines) == 1
    result = subprocess.run(
        ["bash", "-c", lines[0] + '\nprintf "%s" "$expected_output_sha"'],
        env={**os.environ, "nonce1": first, "nonce2": second},
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout


nonce1 = "a" * 32
mutated_nonce1 = "b" * 32
nonce2 = "c" * 32
assert oracle_hash(driver, nonce1, nonce2) == oracle_hash(driver, mutated_nonce1, nonce2)

assert oracle_hash(candidate_sh, nonce1, nonce2) != oracle_hash(candidate_sh, mutated_nonce1, nonce2)
print("OLD: nonce1 mutation is undetected by the current final-file hash")
print("CANDIDATE: the same mutation changes the final-file hash")
