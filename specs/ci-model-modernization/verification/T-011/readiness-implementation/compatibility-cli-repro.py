"""Real old planner CLI, existing local GitFixture; never hosted execution evidence."""
from pathlib import Path
import hashlib
import importlib.util
import json
import os
import subprocess
import sys

HERE = Path(__file__).resolve().parent
OWNED = Path('/workspace/.task-scratch/ci-model-modernization/t011-readiness-implementation/input-snapshot')
spec = importlib.util.spec_from_file_location('old_compat_fixture', OWNED / 'inputs/tests/verification-ci-plan.tests.py')
assert spec is not None and spec.loader is not None
F = importlib.util.module_from_spec(spec)
spec.loader.exec_module(F)
f = F.GitFixture('runTest')
f.setUp()
records = []
try:
    f.git('checkout', '-q', f.base)
    f.workflow['jobs']['cli-hook-enforcement'] = {'runs-on': 'ubuntu-latest', 'steps': [{
        'name': 'Install Claude Code CLI', 'shell': 'bash',
        'run': 'npm install -g --allow-scripts=@anthropic-ai/claude-code @anthropic-ai/claude-code\nclaude --version'}]}
    f.catalog['impact']['non_suite_steps'] = []
    f.write('README.md', '# Baseline README\n')
    f.write('.github/workflows/test.yml', json.dumps(f.workflow))
    f.write('tests/verification-catalog.json', json.dumps(f.catalog))
    base = f.commit('local fixture: old compatible parser, no setup declaration')
    subprocess.run(['git', '-C', str(f.trusted), 'fetch', '-q', str(f.root), base], check=True)
    subprocess.run(['git', '-C', str(f.trusted), 'checkout', '-q', '--detach', base], check=True)
    f.write('README.md', '# Baseline README\n<!-- local small-change control -->\n')
    control_head = f.commit('local fixture: README-only control')

    def invoke(label, head, force):
        command = [sys.executable, '-I', '-B', str(f.trusted / 'tests/verification-impact.py'), '--plan',
            '--root', str(f.root), '--trusted-root', str(f.trusted), '--event', 'pull_request',
            '--run-id', '123', '--run-attempt', '1', '--api-head-sha', head,
            '--tested-revision', head, '--base', base, '--head', head, '--force-full', force]
        result = subprocess.run(command, cwd=f.root, capture_output=True, text=True, timeout=120)
        (HERE / (label + '.stdout')).write_text(result.stdout)
        (HERE / (label + '.stderr')).write_text(result.stderr)
        row = {'case': label, 'command': command, 'exit_code': result.returncode,
               'base': base, 'head': head, 'force_full': force,
               'stdout_json': json.loads(result.stdout) if result.stdout else None,
               'stderr_json': json.loads(result.stderr) if result.stderr else None}
        records.append(row)
        return row

    control = invoke('old-parser-readme-control', control_head, 'false')
    assert control['exit_code'] == 0 and control['stdout_json']['mode'] == 'full'
    f.catalog['impact']['non_suite_steps'] = [{'job': 'cli-hook-enforcement',
        'step': 'Install Claude Code CLI', 'kind': 'setup'}]
    f.write('tests/verification-catalog.json', json.dumps(f.catalog))
    changed = f.commit('local fixture: new setup declaration on old trusted base')
    for force in ('false', 'true'):
        row = invoke('old-parser-new-setup-' + force, changed, force)
        assert row['exit_code'] == 2 and row['stdout_json'] is None
        assert row['stderr_json']['schema'] == 'verification-ci-error/v1'
        assert row['stderr_json']['reason'] == 'input-invalid'
    old_source = OWNED / 'inputs/tests/verification-impact.py'
    record = {'label': 'ACTUAL_LOCAL_OLD_TRUSTED_PLANNER_CLI_NOT_HOSTED_PR_PROOF',
        'fixture_source': 'tests/verification-ci-plan.tests.py:GitFixture',
        'old_parser_sha256': hashlib.sha256(old_source.read_bytes()).hexdigest(),
        'local_git_only': True, 'no_test_or_native_work_execution': True,
        'cases': records,
        'conclusion': 'Old source emits full for compatible README-only control, but typed FAIL/input-invalid (not full) for new setup declaration, even force-full=true. This safe failure does not satisfy full-PR acceptance. No correction applied.'}
    (HERE / 'compatibility-cli-result.json').write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'control': control['stdout_json']['mode'],
        'new_setup_results': [(r['force_full'], r['exit_code'], r['stderr_json']['reason']) for r in records[1:]]}))
finally:
    assert f.doCleanups()
