#!/usr/bin/env python3
"""WFI-061 mutation checks for the narrowed shell target predicate."""
import importlib.util
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

root = Path(__file__).resolve().parents[1]
path = root / "plugins" / "sdd-quality-loop" / "scripts" / "sdd-hook-guard.py"
spec = importlib.util.spec_from_file_location("guard", path)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

def old_whole_command_predicate(command):
    return (
        guard.SDD_SUDO_NAME.lower() in command.lower()
        and guard.SHELL_SUDO_WRITE_RE.search(command) is not None
    )

allow_cases = [
    "python3 -c \"print('SDD_SUDO > docs')\"",
    "echo SDD_SUDO > /tmp/other",
    "echo foo > /tmp/SDD_SUDO_KEY",
]
deny_cases = [
    "printf x > /tmp/SDD_SUDO",
    "rm /tmp/SDD_SUDO",
]

for command in allow_cases:
    assert old_whole_command_predicate(command), command
    assert not guard._shell_targets_sdd_sudo(command), command
for command in deny_cases:
    assert guard._shell_targets_sdd_sudo(command), command

source = path.read_text()
assert "if SDD_SUDO_NAME.lower() not in cmd.lower():" not in source
assert "if SHELL_SUDO_WRITE_RE.search(cmd):" not in source
print("wfi061 mutation checks: 5 passed")

# Exercise the documented signer itself; no real key or SDD_SUDO token is used.
document = (root / "plugins/sdd-quality-loop/skills/sdd-sudo/SKILL.md").read_text()
match = re.search(r"python3 -c '\n(.*?)\n'", document, re.S)
assert match, "documented Python signer is missing"
program = match.group(1)
expected = "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843"
message = b"what do ya want for nothing?"  # RFC4231 test case2, key Jefe.
with tempfile.TemporaryDirectory() as directory:
    fixture_home = Path(directory)
    (fixture_home / ".sdd").mkdir()
    (fixture_home / ".sdd/sudo-key").write_bytes(b"Jefe\n")
    override = fixture_home / "override key"
    override.write_bytes(b"\xef\xbb\xbfJefe \t\r\n")
    base_env = dict(os.environ, HOME=directory, USERPROFILE=directory)
    base_env.pop("SDD_SUDO_KEY", None)
    base_env.pop("SDD_SUDO_KEY_FILE", None)
    for extra in ({}, {"SDD_SUDO_KEY_FILE": str(override)},
                  {"SDD_SUDO_KEY": "Jefe", "SDD_SUDO_KEY_FILE": str(fixture_home / "missing")}):
        result = subprocess.run([sys.executable, "-c", program], input=message,
                                capture_output=True, env={**base_env, **extra}, timeout=10)
        assert result.returncode == 0, result.stderr
        assert result.stdout.decode().strip() == expected
    for extra in ({"SDD_SUDO_KEY_FILE": str(fixture_home / "missing")},
                  {"SDD_SUDO_KEY_FILE": str(fixture_home / "empty")}):
        (fixture_home / "empty").write_bytes(b" \n")
        result = subprocess.run([sys.executable, "-c", program], input=message,
                                capture_output=True, env={**base_env, **extra}, timeout=10)
        assert result.returncode != 0 and not result.stdout
    process = subprocess.Popen([sys.executable, "-c", program], stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               env={**base_env, "SDD_SUDO_KEY": "fixture-key-not-secret"})
    try:
        assert all("fixture-key-not-secret" not in arg for arg in process.args)
        proc_args = Path(f"/proc/{process.pid}/cmdline")
        if proc_args.exists():
            assert b"fixture-key-not-secret" not in proc_args.read_bytes()
        stdout, stderr = process.communicate(message, timeout=10)
        assert process.returncode == 0 and len(stdout.strip()) == 64, stderr
    finally:
        if process.poll() is None:
            process.kill()
            process.communicate(timeout=10)
print("documented signer: RFC4231/three key sources/two failures/no-key-argv controls passed")
