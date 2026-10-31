"""Capture the tightened T-003 RED run without replacing earlier evidence."""
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[6]
result = subprocess.run([sys.executable, str(root / 'tests/sdd-domain-multitarget-T-003.tests.py')],
                        cwd=root, capture_output=True)
log = Path(__file__).with_name('red-final.log')
with log.open('xb') as handle:
    handle.write(result.stdout + result.stderr)
    handle.write(f'\nEXIT_CODE={result.returncode}\n'.encode())
print((result.stdout + result.stderr).decode(errors='replace'))
print(f'EXIT_CODE={result.returncode}')
raise SystemExit(result.returncode)
