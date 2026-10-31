#!/usr/bin/env python3
"""Candidate-only runtime oracle probe. No agent CLI, source edits or reservations."""
import hashlib
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
sources = {ext: (ROOT / f"tests/cross-runtime-handoff.tests.{ext}").read_text() for ext in ("sh", "ps1")}

def unique(ext, prefix):
    matches = [line.strip() for line in sources[ext].splitlines() if line.strip().startswith(prefix)]
    assert len(matches) == 1, (ext, prefix, len(matches))
    return matches[0]

old_sh = unique("sh", "expected_output_sha=$(")
assert old_sh.count("printf 'COPILOT-CONSUMED:%s' \"$nonce2\"") == 1
new_sh = old_sh.replace("printf 'COPILOT-CONSUMED:%s' \"$nonce2\"", "printf 'COPILOT-CONSUMED:%s:%s' \"$nonce1\" \"$nonce2\"")
old_ps = unique("ps1", "$outputBytes = ")
assert old_ps == "$outputBytes = [Text.Encoding]::UTF8.GetBytes('COPILOT-CONSUMED:' + $nonce2)"
new_ps = old_ps.replace("+ $nonce2", "+ $nonce1 + ':' + $nonce2")
ps_hash = unique("ps1", "$expectedOutput = ")

def evaluate(ext, candidate, first, second):
    # Controlled hexadecimal values only; never execute whole drivers or their live CLI paths.
    assert len(first) == len(second) == 32 and set(first + second) <= set("abcdef0123456789")
    if ext == "sh":
        script = f"nonce1='{first}'\nnonce2='{second}'\n" + (new_sh if candidate else old_sh) + '\nprintf "%s" "$expected_output_sha"\n'
        command = ["bash", "-s"]
    else:
        script = f"$nonce1='{first}'\n$nonce2='{second}'\n" + (new_ps if candidate else old_ps) + '\n' + ps_hash + '\n[Console]::Write($expectedOutput)\n'
        command = ["pwsh", "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script]
    result = subprocess.run(command, input=script if ext == "sh" else None, text=True, capture_output=True, check=True)
    assert not result.stderr, result.stderr
    digest = result.stdout.strip()
    assert len(digest) == 64 and set(digest) <= set("0123456789abcdef"), repr(digest)
    return digest

first, second = "a" * 32, "c" * 32
cases = [("baseline", first, second), ("nonce1-only", "b" * 32, second), ("nonce2-only", first, "d" * 32)]
for ext in sources:
    for candidate in (False, True):
        results = {name: evaluate(ext, candidate, one, two) for name, one, two in cases}
        prefix = "CANDIDATE" if candidate else "CURRENT"
        for name, one, two in cases:
            expected_bytes = f"COPILOT-CONSUMED:{one}:{two}".encode() if candidate else f"COPILOT-CONSUMED:{two}".encode()
            assert results[name] == hashlib.sha256(expected_bytes).hexdigest()
        for name in ("nonce1-only", "nonce2-only"):
            rejects_stale = results[name] != results["baseline"]
            assert rejects_stale == (candidate or name == "nonce2-only")
            print(f"{prefix} {ext} {name}: stale-baseline-output {'REJECTED' if rejects_stale else 'ACCEPTED (defect)'}")
        if candidate:
            baseline_bytes = f"COPILOT-CONSUMED:{first}:{second}".encode()
            for label, mutant in (("trailing-newline", baseline_bytes + b'\n'), ("utf8-bom", b'\xef\xbb\xbf' + baseline_bytes), ("nonce2-only-output", f"COPILOT-CONSUMED:{second}".encode())):
                assert hashlib.sha256(mutant).hexdigest() != results["baseline"]
                print(f"CANDIDATE {ext} {label}: REJECTED")
print("Probe complete: exact-source oracle expressions executed in Bash and PowerShell; no native-host or formal gate claim.")
