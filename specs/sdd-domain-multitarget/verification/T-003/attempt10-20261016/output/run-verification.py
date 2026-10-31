"""Capture this attempt's command evidence without replacing existing logs."""
from pathlib import Path
import subprocess
import sys

destination = Path(__file__).parent / sys.argv[1]
with destination.open('x', encoding='utf-8') as output:
    result = subprocess.run(sys.argv[2:], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    output.write(result.stdout)
    output.write('\nExit code: ' + str(result.returncode) + '\n')
print(result.stdout, end='')
print('Exit code:', result.returncode)
sys.exit(result.returncode)
