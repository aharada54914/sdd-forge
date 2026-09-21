#!/usr/bin/env python3
"""WFI-061 mutation checks for the narrowed shell target predicate."""
import importlib.util
import re
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
    "python3 -c \"open('/tmp/SDD_SUDO','w').write('x')\"",
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
