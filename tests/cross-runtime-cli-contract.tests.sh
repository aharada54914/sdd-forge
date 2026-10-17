#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
python3 - "$root" <<'PY'
import os, pathlib, subprocess, sys
root = pathlib.Path(sys.argv[1])
required = ['SDD_A8_' + 'CODEX_BIN', 'gpt-5.6-' + 'sol', 'son' + 'net', 'SDD_A8_' + 'COPILOT_MODEL']
def valid(source):
    return '--permission-' + 'prompts' not in source and all(token in source for token in required)
for suffix in ('sh', 'ps1'):
    source = (root / ('tests/cross-runtime-handoff.tests.' + suffix)).read_text()
    if suffix == 'sh':
        live = source.split('\nrequire_cli() {', 1)[1].split('\nstatus=$(task_status', 1)[0]
    else:
        live = source.split('\nfunction Invoke-LiveE2E {', 1)[1].split('\nif ($SelfTestActivation)', 1)[0]
    assert valid(live), suffix + ': invalid native live CLI contract'
    tool_arguments = {
        'sh': [('--available-' + "tools='view,create'"), ('--allow-' + 'tool=' + '"write($output_file)"')],
        'ps1': [('--available-' + 'tools=view,create'), ('--allow-' + 'tool=write($output)')],
    }[suffix]
    for argument in tool_arguments:
        assert live.count(argument) == 1, suffix + ': missing or ambiguous scoped Copilot tool argument: ' + argument
    assert live.count('You may use a read-only shell command to read that file.') == 1, suffix + ': Codex consumer cannot read its fixture'
    assert live.count('Do not modify files or read anything else.') == 1, suffix + ': Codex consumer scope changed'
    assert live.count('Read,Edit,Bash(rtk proxy rg:*)') == 1, suffix + ': Claude producer lost scoped read-only search permission'
    assert live.count('Do not modify any other file or run any other shell command.') == 1, suffix + ': Claude producer scope changed'
    assert live.count('using read-only rtk proxy sed commands.') == 1, suffix + ': Codex producer cannot read its fixtures'
    assert live.count('Do not run any other shell command or modify any other file.') == 1, suffix + ': Codex producer scope changed'
    sandbox = '--sandbox read-only' if suffix == 'sh' else "'--sandbox', 'read-only'"
    assert sandbox in live, suffix + ': Codex consumer lost read-only sandbox'
    if suffix == 'sh':
        guards = [line for line in live.splitlines() if line.startswith('[[ ') and required[3] in line]
        assert len(guards) == 1, 'missing or ambiguous Copilot model guard'
        for model in ('', 'auto', 'Auto', 'AUTO', 'claude-sonnet-4.6'):
            result = subprocess.run(['bash', '-c', 'fail() { return 1; }; ' + guards[0]],
                                    env={**os.environ, required[3]: model}, capture_output=True)
            assert (result.returncode == 0) == (model == 'claude-sonnet-4.6'), 'Copilot model guard accepted unpinned selection: ' + repr(model)
    for token in required:
        assert not valid(live.replace(token, 'REMOVED')), suffix + ': insensitive live-token mutation'
print('ok: native live CLI contract and all eight missing-token mutations')
print('ok: Bash live Copilot model guard rejects empty and case-variant automatic selections')
PY
