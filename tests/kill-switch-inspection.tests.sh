#!/usr/bin/env bash
# Actual filesystem errors and compatibility controls for the standalone hook.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
python3 - "$repo/plugins/sdd-quality-loop/scripts/kill-switch.sh" <<'PY'
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(tempfile.mkdtemp(prefix="kill switch ' 日本語 "))
root.chmod(0o755)
hook = root / 'kill-switch.sh'
shutil.copyfile(sys.argv[1], hook)
hook.chmod(0o644)
clean = root / 'clean'
clean.mkdir()
count = 0

def run(name, base, expected, cwd=clean, unprivileged=False):
    global count
    env = dict(os.environ, CLAUDE_PROJECT_DIR=str(base))
    def drop_privileges():
        os.setgroups([])
        os.setgid(65534)
        os.setuid(65534)
    result = subprocess.run(['/bin/sh', str(hook)], cwd=cwd, env=env,
                            capture_output=True, text=True,
                            preexec_fn=drop_privileges if unprivileged and os.geteuid() == 0 else None)
    assert result.returncode == expected, (name, result.returncode, result.stderr)
    assert not result.stdout, (name, result.stdout)
    if 'inaccessible' in name:
        assert 'cannot inspect' in result.stderr, (name, result.stderr)
    count += 1
    print('PASS:', name)

blocked = root / 'blocked'
blocked.mkdir()
(blocked / 'AGENT_STOP').touch()
try:
    run('absent marker', clean, 0)
    run('absent optional nested root', root / 'missing' / 'nested', 0)
    run('present marker', blocked, 2)
    (clean / 'AGENT_STOP').symlink_to(blocked / 'AGENT_STOP')
    run('marker symlink to file', clean, 2)
    (clean / 'AGENT_STOP').unlink()
    (clean / 'AGENT_STOP').symlink_to(root / 'missing')
    run('dangling marker symlink', clean, 0)
    (clean / 'AGENT_STOP').unlink()
    (clean / 'AGENT_STOP').mkdir()
    run('directory marker', clean, 0)
    (clean / 'AGENT_STOP').rmdir()
    (clean / 'cycle').symlink_to('cycle')
    run('unrelated cyclic symlink', clean, 0)
    (root / 'root-link').symlink_to(clean, target_is_directory=True)
    run('root symlink', root / 'root-link', 0)
    (root / 'dangling-root').symlink_to(root / 'missing')
    run('dangling optional root', root / 'dangling-root', 0)
    (clean / '-leading').mkdir()
    run('leading hyphen root', '-leading', 0)
    blocked.chmod(0)
    run('inaccessible root', blocked, 2, unprivileged=True)
    run('inaccessible nested optional root', blocked / 'missing', 2, unprivileged=True)
    (clean / 'AGENT_STOP').symlink_to(blocked / 'AGENT_STOP')
    run('inaccessible marker symlink target', clean, 2, unprivileged=True)
    (clean / 'AGENT_STOP').unlink()
    (root / 'hidden-root-link').symlink_to(blocked / 'missing')
    run('inaccessible optional root symlink target', root / 'hidden-root-link', 2, unprivileged=True)
    blocked.chmod(0o755)
    # CWD must still be checked when an optional configured root is absent.
    run('cwd stop with absent configured root', root / 'missing', 2, cwd=blocked)
finally:
    blocked.chmod(0o755)
    shutil.rmtree(root)
print(f'{count} assertions passed')
PY
