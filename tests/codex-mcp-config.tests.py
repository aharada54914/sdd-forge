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
parser.add_argument('--bash', default='bash')
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
    for file, function in [
        ('install.sh', 'filter_codex_block'),
        ('install.sh', 'register_codex_mcp'),
        ('uninstall.sh', 'unregister_codex_mcp'),
    ]:
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
    for runtime, command in [('bash', [args.bash, str(bash_driver)]), ('powershell', [args.pwsh, '-NoProfile', '-File', str(ps_driver)])]:
        def run(action):
            return subprocess.run(command + [action], env=env, capture_output=True, text=True, timeout=30)
        def check(label, condition):
            global count
            count += 1
            print(f'{"PASS" if condition else "FAIL"}: {runtime}: {label}')
            if not condition:
                failures.append(f'{runtime}: {label}')
        for malformed, content in [
            ('missing end', begin + '\ncommand = "node"\n'),
            ('nested begin', begin + '\n' + begin + '\n' + end + '\n'),
            ('orphan end', end + '\n'),
            ('duplicate block', begin + '\n[mcp_servers.sdd-forge-mcp]\ncommand = "node"\n' + end + '\n' + begin + '\n[mcp_servers.sdd-forge-mcp]\ncommand = "node"\n' + end + '\n'),
        ]:
            for action in ['install', 'uninstall']:
                if malformed == 'duplicate block' and action == 'uninstall':
                    continue
                # Ordinary payload ensures malformed-marker checks reach both functions.
                env['TEST_PAYLOAD'] = str(ordinary_payload)
                original = ('title = "user"\n' + content + '[user_settings]\nkeep = true\n').encode()
                config.write_bytes(original)
                result = run(action)
                check(f'{action} rejects {malformed} and preserves bytes', result.returncode != 0 and config.read_bytes() == original and 'Malformed managed MCP markers' in result.stderr)

        # V-02: Preserve per-tool sub-tables (e.g. [mcp_servers.<name>.tools]) and table order in place.
        env['TEST_PAYLOAD'] = str(ordinary_payload)
        with_tools = (
            'title = "user"\n\n'
            + begin + '\n'
            + '[mcp_servers.sdd-forge-mcp]\n'
            + 'command = "node"\n'
            + 'args = ["/old/path/dist/index.js"]\n'
            + 'startup_timeout_sec = 30\n\n'
            + '[mcp_servers.sdd-forge-mcp.tools.sdd_gate_audit]\n'
            + 'approval_mode = "approve"\n'
            + end + '\n\n'
            + '[user_settings]\n'
            + 'keep = true\n'
        )
        config.write_text(with_tools)
        result = run('install')
        updated_text = config.read_text()
        try:
            data = tomllib.loads(updated_text)
            preserved = (
                data['mcp_servers'][name]['command'] == 'node'
                and data['mcp_servers'][name]['args'] == [str(ordinary_entry)]
                and data['mcp_servers'][name]['startup_timeout_sec'] == 30
                and data['mcp_servers'][name]['tools']['sdd_gate_audit'] == {'approval_mode': 'approve'}
                and data['user_settings']['keep'] is True
                and data['title'] == 'user'
                and updated_text.index(begin) < updated_text.index('[user_settings]')
            )
        except (ValueError, KeyError):
            preserved = False
        check('V-02 preserves per-tool sub-table, extra keys, and block order on re-install', result.returncode == 0 and preserved)

        # V-02: Case-insensitive markers are also updated in place while preserving tool settings.
        upper_begin = f'# >>> {name.upper()} (managed by sdd-forge installer; do not edit by hand) >>>'
        upper_end = f'# <<< {name.upper()} <<<'
        config.write_text(
            'title = "user"\n'
            + upper_begin + '\n'
            + '[mcp_servers.sdd-forge-mcp]\n'
            + 'command = "node"\n'
            + 'args = ["/old/index.js"]\n'
            + '[mcp_servers.sdd-forge-mcp.tools]\n'
            + 'allow_all = true\n'
            + upper_end + '\n'
            + '[user_settings]\nkeep = true\n'
        )
        result = run('install')
        try:
            data = tomllib.loads(config.read_text())
            ci_ok = (
                data['mcp_servers'][name]['args'] == [str(ordinary_entry)]
                and data['mcp_servers'][name]['tools'] == {'allow_all': True}
            )
        except (ValueError, KeyError):
            ci_ok = False
        check('V-02 updates case-insensitive markers in place while keeping tool settings', result.returncode == 0 and ci_ok)

        # Explicit uninstall removes the managed block including its nested tool sub-tables.
        result = run('uninstall')
        try:
            data = tomllib.loads(config.read_text())
            removed = data == {'title': 'user', 'user_settings': {'keep': True}}
        except ValueError:
            removed = False
        check('V-02 explicit uninstall removes server and nested tool settings', result.returncode == 0 and removed)
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

    # V-01: Detecting retired sdd-lite@sdd-plugins residue on Codex upgrade.
    v01_home = root / 'codex-v01'
    (v01_home / 'plugins/cache/sdd-plugins/sdd-lite/1.25.0').mkdir(parents=True)
    (v01_home / 'config.toml').write_text('[plugins."sdd-lite@sdd-plugins"]\nenabled = true\n')
    fake_bin = root / 'fake-bin'
    fake_bin.mkdir()
    fake_codex = fake_bin / 'codex'
    fake_codex.write_text('#!/bin/sh\nexit 0\n')
    fake_codex.chmod(0o755)
    v01_env = dict(os.environ, SDD_CODEX_HOME=str(v01_home), PATH=f'{fake_bin}:{os.environ.get("PATH", "")}')
    install_codex_match = re.search(r'^install_codex_plugins\(\) \{\n.*?^\}', (repo / 'install.sh').read_text(), re.M | re.S)
    assert install_codex_match, 'install_codex_plugins'
    v01_sh = root / 'v01.sh'
    v01_sh.write_text(
        'set -euo pipefail\n'
        'SKIP_PLUGIN_INSTALL=0\n'
        'PLUGIN_LIST=(sdd-bootstrap)\n'
        'target_requires() { return 0; }\n'
        'run_idempotent_plugin_command() { shift; "$@"; }\n'
        + install_codex_match.group()
        + '\ninstall_codex_plugins "$1"\n'
    )
    res_sh = subprocess.run([args.bash, str(v01_sh), str(root)], env=v01_env, capture_output=True, text=True, timeout=30)
    count += 1
    sh_ok = res_sh.returncode == 0 and 'sdd-lite@sdd-plugins' in res_sh.stderr and 'uninstall.sh' in res_sh.stderr
    print(f'{"PASS" if sh_ok else "FAIL"}: bash: V-01 warns about retired sdd-lite@sdd-plugins residue')
    if not sh_ok:
        failures.append(f'bash: V-01 warning missing: {res_sh.stderr}')

    v01_ps = root / 'v01.ps1'
    v01_ps.write_text('''param([string]$Root)
$ErrorActionPreference = 'Stop'
$tokens = $null; $errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $env:TEST_REPO 'install.ps1'), [ref]$tokens, [ref]$errors)
$fn = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Install-CodexPlugins' }, $true)
. ([scriptblock]::Create($fn.Extent.Text))
function Invoke-IdempotentPluginCommand { param($Label, $Command, $Arguments) }
$Target = 'Codex'
$SkipPluginInstall = $false
$Plugins = @('sdd-bootstrap')
$script:CodexRegistrationStatus = ''
Install-CodexPlugins -MarketplaceRoot $Root
''')
    res_ps = subprocess.run([args.pwsh, '-NoProfile', '-File', str(v01_ps), str(root)], env=dict(v01_env, TEST_REPO=str(repo)), capture_output=True, text=True, timeout=30)
    count += 1
    ps_out = res_ps.stdout + res_ps.stderr
    ps_ok = res_ps.returncode == 0 and 'sdd-lite@sdd-plugins' in ps_out and 'uninstall.ps1' in ps_out
    print(f'{"PASS" if ps_ok else "FAIL"}: powershell: V-01 warns about retired sdd-lite@sdd-plugins residue')
    if not ps_ok:
        failures.append(f'powershell: V-01 warning missing: {ps_out}')
print(f'{count - len(failures)}/{count} passed')
raise SystemExit(bool(failures))
