"""Read-only admission and exit-propagation check for the unapplied CI patch."""
import pathlib
import re
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
PATCH = pathlib.Path(__file__).with_name('issue423-windows-resolver-ci-candidate-20261001.patch')


def check():
    subprocess.run(['git', 'apply', '--check', str(PATCH)], cwd=ROOT, check=True)
    lines = PATCH.read_text().splitlines()
    assert not any(line.startswith('-') and not line.startswith('---') for line in lines)
    added = '\n'.join(line[1:] for line in lines if line.startswith('+') and not line.startswith('+++'))
    assert "        if: runner.os == 'Windows'" in added
    assert 'continue-on-error' not in added
    paths = re.findall(r"'\./(tests/[^']+\.tests\.ps1)'", added)
    inventory = (ROOT / 'tests/run-all.ps1').read_text()
    registered = re.findall(r"'(tests/(?:resolver-evidence-schema|resolve-project-context-[^']+|validate-resolver-evidence)\.tests\.ps1)'", inventory)
    assert paths == registered and len(paths) == len(set(paths)) == 10
    assert all((ROOT / path).is_file() for path in paths)
    body = added.split('        run: |\n', 1)[1]
    body = '\n'.join(line[10:] for line in body.splitlines())
    declaration = '$powerShell = (Get-Process -Id $PID).Path'
    assert body.count(declaration) == 1
    body = body.replace(declaration, "$powerShell = 'Probe'")
    for fail_at, expected_exit, expected_calls in ((0, 0, 10), (4, 7, 4)):
        probe = f'''$global:calls = 0
function Probe {{
  param([switch]$NoProfile, [switch]$NonInteractive, [string]$File)
  $global:calls++
  Write-Output "CALL:$File"
  $global:LASTEXITCODE = if ($global:calls -eq {fail_at}) {{ 7 }} else {{ 0 }}
}}
'''
        run = subprocess.run(['pwsh', '-NoProfile', '-NonInteractive', '-Command', probe + body],
                             cwd=ROOT, capture_output=True, text=True, timeout=30)
        assert run.returncode == expected_exit, run.stdout + run.stderr
        assert len(re.findall(r'^CALL:', run.stdout, re.M)) == expected_calls, run.stdout
    print('PASS: exact ten-suite admission, insertion-only patch, success and fail-fast exits')


if __name__ == '__main__':
    check()
