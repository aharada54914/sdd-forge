#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
python3 - "$ROOT" <<'PY'
import os
import re
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(sys.argv[1])
lines = (root / '.github/workflows/test.yml').read_text().splitlines()
pins = [line.split(':', 1)[1].strip().strip('"') for line in lines
        if line.strip().startswith('CLAUDE_CLI_VERSION:')]
assert len(pins) == 1 and re.fullmatch(r'[0-9]+\.[0-9]+\.[0-9]+', pins[0]), pins
commands = []
for index, line in enumerate(lines):
    if line.strip() not in ('- name: Install recorded Claude Code CLI',
                            '- name: Install Claude Code CLI'):
        continue
    for offset in range(index + 1, len(lines)):
        item = lines[offset]
        if item.lstrip().startswith('run:'):
            value = item.split('run:', 1)[1].strip()
            if value == '|':
                indent = len(item) - len(item.lstrip())
                block = []
                for child in lines[offset + 1:]:
                    if child.strip() and len(child) - len(child.lstrip()) <= indent:
                        break
                    block.append(child.strip())
                value = '\n'.join(block)
            package = '@anthropic-ai/claude-code'
            if '${{ env.CLAUDE_CLI_VERSION }}' in value:
                value = value.replace('${{ env.CLAUDE_CLI_VERSION }}', pins[0])
                package += '@' + pins[0]
            commands.append((value, package))
            break
assert len(commands) == 2, 'both existing installation steps must be exercised'

with tempfile.TemporaryDirectory(prefix='ci-claude-install-') as directory:
    scratch = Path(directory)
    for name, body in {
        'npm': 'printf "npm:%s\\n" "$*" >> "$CALLS"\nexit "$INSTALL_EXIT"\n',
        'claude': 'printf "claude:%s\\n" "$*" >> "$CALLS"\nexit "$STARTUP_EXIT"\n',
    }.items():
        stub = scratch / name
        stub.write_text('#!/bin/sh\n' + body)
        stub.chmod(0o700)
    for lane, (command, package) in enumerate(commands):
        for install_exit, startup_exit in ((0, 0), (17, 0), (0, 19)):
            log = scratch / 'calls'
            log.write_text('')
            env = dict(os.environ, PATH=f'{scratch}:{os.environ["PATH"]}',
                       CALLS=str(log), INSTALL_EXIT=str(install_exit),
                       STARTUP_EXIT=str(startup_exit))
            result = subprocess.run(['bash', '--noprofile', '--norc', '-eo',
                                     'pipefail', '-c', command], env=env)
            calls = log.read_text().splitlines()
            assert calls[0] == ('npm:install -g --allow-scripts=@anthropic-ai/claude-code '
                                f'{package}'), calls
            assert calls[1:] == ([] if install_exit else ['claude:--version']), calls
            assert result.returncode == (install_exit or startup_exit), result
            print(f'ok: lane {lane}: install={install_exit}, startup={startup_exit}')
print('Claude installation workflow: 6 passed')
PY
