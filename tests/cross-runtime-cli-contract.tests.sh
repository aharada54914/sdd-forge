#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
python3 - "$root" <<'PY'
import pathlib, sys
root = pathlib.Path(sys.argv[1])
required = ['SDD_A8_' + 'CODEX_BIN', 'gpt-6-' + 'sol', 'son' + 'net', 'SDD_A8_' + 'COPILOT_MODEL']
def valid(source):
    return '--permission-' + 'prompts' not in source and all(token in source for token in required)
for suffix in ('sh', 'ps1'):
    source = (root / ('tests/cross-runtime-handoff.tests.' + suffix)).read_text()
    if suffix == 'sh':
        live = source.split('\nrequire_cli() {', 1)[1].split('\nstatus=$(task_status', 1)[0]
    else:
        live = source.split('\nfunction Invoke-LiveE2E {', 1)[1].split('\nif ($SelfTestActivation)', 1)[0]
    assert valid(live), suffix + ': invalid native live CLI contract'
    for token in required:
        assert not valid(live.replace(token, 'REMOVED')), suffix + ': insensitive live-token mutation'
print('ok: native live CLI contract and all eight missing-token mutations')
PY
