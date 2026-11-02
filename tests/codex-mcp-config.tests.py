#!/usr/bin/env python3
"""Exercise actual Codex config functions without installer placement/network effects."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import tempfile
import tomllib

parser = argparse.ArgumentParser()
parser.add_argument('--repo', type=Path, default=Path(__file__).resolve().parents[1])
parser.add_argument('--pwsh', default='pwsh')
args = parser.parse_args()
repo = args.repo.resolve()
name = 'sdd-forge-mcp'
begin = f'# >>> {name} (managed by sdd-forge installer; do not edit by hand) >>>'
end = f'# <<< {name} <<<'
failures = []
count = 0
with tempfile.TemporaryDirectory(prefix='codex-config-') as scratch:
    root = Path(scratch)
    home = root / 'codex'
    home.mkdir()
    config = home / 'config.toml'
    # Linux allows all these path characters; exercise serialized data, not code.
    payload = root / ('payload "\\\n\t\r' + ''.join(chr(i) for i in range(1, 32)) + '\x7f-日本語')
    entry = payload / 'mcp' / name / 'dist/index.js'
    entry.parent.mkdir(parents=True)
    entry.touch()
    ordinary_payload = root / 'ordinary payload'
    ordinary_entry = ordinary_payload / 'mcp' / name / 'dist/index.js'
    ordinary_entry.parent.mkdir(parents=True)
    ordinary_entry.touch()
    env = dict(os.environ, SDD_CODEX_HOME=str(home), TEST_REPO=str(repo), TEST_PAYLOAD=str(payload))
    bash_functions = []
    for file, function in [('install.sh', 'register_codex_mcp'), ('uninstall.sh', 'unregister_codex_mcp')]:
        match = re.search(r'^' + function + r'\(\) \{\n.*?^\}', (repo / file).read_text(), re.M | re.S)
        assert match, function
        bash_functions.append(match.group())
    bash_driver = root / 'driver.sh'
    bash_driver.write_text('set -euo pipefail\n' + '\n'.join(bash_functions) + '''
MCP_SELECTION=(sdd-forge-mcp)
SKIP_MCP_UNINSTALL=0
if [[ $1 == install ]]; then register_codex_mcp "$TEST_PAYLOAD"; else unregister_codex_mcp; fi
''')
    ps_driver = root / 'driver.ps1'
    ps_driver.write_text('''param([string]$Action)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
foreach ($pair in @(@('install.ps1','Register-CodexMcp'), @('uninstall.ps1','Unregister-CodexMcp'))) {
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $env:TEST_REPO $pair[0]), [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw 'Parse failed' }
    $function = $ast.Find({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $pair[1] }, $true)
    . ([scriptblock]::Create($function.Extent.Text))
}
$Mcp = @('sdd-forge-mcp')
$SkipMcpUninstall = $false
if ($Action -eq 'install') { Register-CodexMcp -InstallRootPath $env:TEST_PAYLOAD } else { Unregister-CodexMcp }
''')
    for runtime, command in [('bash', ['bash', str(bash_driver)]), ('powershell', [args.pwsh, '-NoProfile', '-File', str(ps_driver)])]:
        def run(action):
            return subprocess.run(command + [action], env=env, capture_output=True, text=True, timeout=30)
        def check(label, condition):
            global count
            count += 1
            print(f'{"PASS" if condition else "FAIL"}: {runtime}: {label}')
            if not condition:
                failures.append(f'{runtime}: {label}')
        for malformed, content in [('missing end', begin + '\ncommand = "node"\n'), ('nested begin', begin + '\n' + begin + '\n' + end + '\n'), ('orphan end', end + '\n')]:
            for action in ['install', 'uninstall']:
                # Ordinary payload ensures malformed-marker checks reach both functions.
                env['TEST_PAYLOAD'] = str(ordinary_payload)
                original = ('title = "user"\n' + content + '[user_settings]\nkeep = true\n').encode()
                config.write_bytes(original)
                result = run(action)
                check(f'{action} rejects {malformed} and preserves bytes', result.returncode != 0 and config.read_bytes() == original and 'Malformed managed MCP markers' in result.stderr)
        for label, install_payload, expected_entry in [('ordinary', ordinary_payload, ordinary_entry), ('escaped', payload, entry)]:
            # PowerShell normalizes separators; use a real Linux path without backslash.
            if runtime == 'powershell' and label == 'escaped':
                install_payload = Path(str(payload).replace('\\', ''))
                expected_entry = install_payload / 'mcp' / name / 'dist/index.js'
                expected_entry.parent.mkdir(parents=True, exist_ok=True)
                expected_entry.touch()
            env['TEST_PAYLOAD'] = str(install_payload)
            config.write_text('title = "user"\n' + begin + '\n[mcp_servers.sdd-forge-mcp]\ncommand = "old"\n' + end + '\n[user_settings]\nkeep = true\n')
            for attempt in range(2):
                result = run('install')
                try:
                    data = tomllib.loads(config.read_text())
                    valid = data['mcp_servers'][name] == {'command': 'node', 'args': [str(expected_entry)]} and data['user_settings']['keep'] and data['title'] == 'user'
                except (ValueError, KeyError):
                    valid = False
                check(f'{label} registration {attempt + 1} parses and round-trips path', result.returncode == 0 and valid)
            result = run('uninstall')
            try:
                data = tomllib.loads(config.read_text())
                valid = data == {'title': 'user', 'user_settings': {'keep': True}}
            except ValueError:
                valid = False
            check(f'{label} uninstall preserves unrelated settings', result.returncode == 0 and valid)
print(f'{count - len(failures)}/{count} passed')
raise SystemExit(bool(failures))
