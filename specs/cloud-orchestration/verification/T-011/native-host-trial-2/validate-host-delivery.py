"""Validate captured native trial evidence; never substitutes another model run."""
from pathlib import Path
import hashlib
import json

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    assets = json.loads((HERE / 'asset-hashes.json').read_text())
    for relative, expected in assets.items():
        path = (HERE / relative).resolve()
        assert path.is_relative_to(HERE) and digest(path) == expected, relative
    bindings = json.loads((HERE / 'current-source-binding.json').read_text())
    for relative, expected in bindings.items():
        assert digest(ROOT / relative) == expected, relative
    setup = json.loads((HERE / 'setup.json').read_text())
    assert len(setup['active_plugins']) == 8 and setup['installed_and_cache_file_count'] == len(setup['sha256'])
    hooks = json.loads((HERE / 'hook-discovery.json').read_text())
    assert len(hooks['data']) == 2
    for entry in hooks['data']:
        assert not entry['errors'] and not entry['warnings']
        assert len(entry['hooks']) == 2
        assert all(h['enabled'] and h['trustStatus'] == 'trusted' for h in entry['hooks'])
    for provider in ('azure', 'aws'):
        executions = json.loads((HERE / f'{provider}-hook-executions.json').read_text())
        assert executions and all(h['source'] == 'plugin' for h in executions)
        assert any(h['status'] == 'completed' for h in executions)
    acceptance = json.loads((HERE / 'acceptance.json').read_text())
    assert acceptance['result'] == 'PASS'
    cases = acceptance['cases']
    assert {case['provider'] for case in cases} == {'azure', 'aws'}
    assert len({case['run_id'] for case in cases}) == 2
    for case in cases:
        provider = case['provider']
        identity = json.loads((HERE / f'{provider}-identity.json').read_text())
        delivery = json.loads((HERE / f'{provider}-delivery.json').read_text())
        assert identity['thread_id'] == delivery['thread_id'] == case['run_id']
        assert delivery['turn_status'] == 'completed' and delivery['error'] is None
        assert digest(HERE / f'{provider}-prompt.txt') == identity['prompt_sha256']
        rows = case['observed']
        assert len(rows) == 5
        assert [r['exit_code'] for r in rows] == [0, 0, 2, 2, 2]
        assert [r['result']['error_code'] for r in rows] == [None, None, 'OPERATION_UNIMPLEMENTED', 'OPERATION_UNIMPLEMENTED', 'OWNER_CONFLICT']
        for row in rows:
            value = row['result']
            assert value['provider'] == provider and 'native_operation_id' not in value
            assert value['state'] == ('ROUTED' if row['exit_code'] == 0 else 'BLOCKED')
        first, second = [dict(r['result']) for r in rows[:2]]
        first.pop('evidence_manifest_path')
        second.pop('evidence_manifest_path')
        assert first == second
        assert case['requests_unchanged'] and case['route_manifest_parity']
    restored = json.loads((HERE / 'profile-restoration.json').read_text())
    assert restored['exact_backup_restored']
    print('PASS: two actual native contexts, ten CLI calls, exact captured assets/source pins, and profile restoration. No live cloud acceptance.')


if __name__ == '__main__':
    main()
