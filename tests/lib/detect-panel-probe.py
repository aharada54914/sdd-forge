"""Exercise the detector's version deadline with disposable native commands."""
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

script = Path(sys.argv[1]).resolve()
host = sys.argv[2]
powershell = script.suffix == '.ps1'
with tempfile.TemporaryDirectory(prefix='sdd version probe ') as temporary:
    root = Path(temporary)
    worker = root / 'probe.py'
    receipt = root / 'pid.txt'
    worker.write_text('''import os, signal, sys, time
from pathlib import Path
Path(os.environ['SDD_TEST_PROBE_PID']).write_text(str(os.getpid()))
mode = os.environ['SDD_TEST_PROBE_MODE']
if mode == 'hang':
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    while True: time.sleep(1)
print('version fixture')
sys.exit(9 if mode == 'fail' else 0)
''', encoding='utf-8')
    command = root / ('gemini.cmd' if os.name == 'nt' else 'gemini')
    if os.name == 'nt':
        command.write_text('@echo off\r\n"' + sys.executable + '" "' + str(worker) + '" %*\r\n', encoding='utf-8')
    else:
        # The command is the directly supervised process, not a shell parent.
        command.write_text('#!' + sys.executable + '\n' + worker.read_text(encoding='utf-8'), encoding='utf-8')
        command.chmod(0o755)
        for name in ('date', 'sleep', 'readlink', 'bash', 'mkdir'):
            source = shutil.which(name)
            if source:
                (root / name).symlink_to(source)
    env = dict(os.environ, PATH=str(root), SDD_TEST_PROBE_PID=str(receipt))
    invocation = [host, '-NoProfile', '-File', str(script), '-Quiet'] if powershell else [host, str(script), '--quiet']
    for mode, expected in [('success', 0), ('fail', 1), ('hang', 1)]:
        env['SDD_TEST_PROBE_MODE'] = mode
        started = time.monotonic()
        result = subprocess.run(invocation, env=env, capture_output=True, timeout=12)
        elapsed = time.monotonic() - started
        assert result.returncode == expected, (mode, result.returncode, result.stderr)
        assert result.stdout.strip() == (b'gemini' if expected == 0 else b''), (mode, result.stdout)
        assert elapsed < 10, (mode, elapsed)
        if mode == 'hang':
            pid = int(receipt.read_text())
            if os.name == 'nt':
                import ctypes
                kernel = ctypes.WinDLL('kernel32', use_last_error=True)
                kernel.OpenProcess.restype = ctypes.c_void_p
                handle = kernel.OpenProcess(0x00100000, False, pid)
                if handle:
                    try:
                        assert kernel.WaitForSingleObject(ctypes.c_void_p(handle), 0) == 0, ('probe remains alive', pid)
                    finally:
                        kernel.CloseHandle(ctypes.c_void_p(handle))
            else:
                try:
                    os.kill(pid, 0)
                except ProcessLookupError:
                    pass
                else:
                    # Container init may leave an exited descendant as a zombie.
                    status = Path('/proc') / str(pid) / 'stat'
                    assert status.exists() and status.read_text().split(') ', 1)[1].startswith('Z '), ('probe remains alive', pid)
        print(f'{script.name}: {mode}, exit={result.returncode}, elapsed={elapsed:.2f}s')
