#!/usr/bin/env python3
"""Bounded native reduced-stage comparison, with rubric outside each namespace."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import signal
import subprocess
import time

ROOT = Path('/workspace/sdd-forge')
OUT = Path('/workspace/scratch/issue-resolution-20261027/golden-v4')
AUTH = Path('/workspace/.tools/sdd-forge-dev/codex-reauth/auth.json')
spec = importlib.util.spec_from_file_location('golden', ROOT / 'tests/golden-eval.py')
golden = importlib.util.module_from_spec(spec)
spec.loader.exec_module(golden)


def save(path, data):
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')


def command(workspace, profile):
    args = ['bwrap', '--unshare-all', '--share-net', '--new-session', '--die-with-parent']
    for path in ('/usr', '/bin', '/lib', '/lib64', '/etc/ssl', '/etc/resolv.conf',
                 '/etc/hosts', '/etc/nsswitch.conf'):
        args += ['--ro-bind', path, path]
    args += ['--ro-bind', '/opt/codex/bin', '/opt/codex/bin', '--proc', '/proc',
             '--dev', '/dev', '--tmpfs', '/tmp', '--bind', str(workspace), '/project',
             '--bind', str(profile), '/profile', '--ro-bind', str(AUTH), '/profile/auth.json',
             '--setenv', 'CODEX_HOME', '/profile', '--setenv', 'HOME', '/tmp/home',
             '--chdir', '/project', '/opt/codex/bin/codex', '--no-daemon', '-a', 'never',
             'exec', '--ephemeral', '--json', '--skip-git-repo-check',
             '--sandbox', 'workspace-write', '--model', 'gpt-6.1-sol',
             '-c', 'model_reasoning_effort="low"', '-c', 'web_search="disabled"',
             'Read input.md and perform that bounded request. Do not inspect authentication files.']
    return args


def main():
    if OUT.exists():
        raise RuntimeError('Never overwrite a previous experiment')
    OUT.mkdir()
    baseline = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'origin/main'], text=True).strip()
    candidate = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    names = ['unrun-pass', 'wrong-routing', 'weak-cleanup', 'overbroad-validation', 'stale-skill']
    conditions = {'model': 'gpt-6.1-sol', 'effort': 'low', 'host': 'Codex CLI 0.159.2 / Linux bwrap namespaces',
                  'tool_permissions': 'native workspace-write, network-denied tool sandbox; outer filesystem/PID namespace; never approvals'}
    experiment = {'schema': 'golden-comparison/v1', 'repetitions': 3, 'cases': names,
                  'timeout_seconds': 75, 'total_seconds_limit': 1800, 'conditions': conditions,
                  'case_sha256': {}, 'input_sha256': {}, 'runs': [], 'variants': {}}
    identity = {'A': baseline, 'B': candidate}
    configs = {}
    for variant, revision in identity.items():
        configs[variant] = {}
        for stage, source in [('implement-task', 'plugins/sdd-implementation/skills/implement-task/SKILL.md'),
                              ('workflow-retrospective', 'plugins/sdd-quality-loop/skills/workflow-retrospective/SKILL.md')]:
            skill = subprocess.check_output(['git', '-C', str(ROOT), 'show', revision + ':' + source], text=True)
            # Equal adaptation: isolate the stage's reduced control, not a full lifecycle simulation.
            instructions = ('This is an isolated reduced-stage work request. Use the following framework stage as context. '
                            'Only perform the natural request in input.md; no surrounding lifecycle, git operations, '
                            'delegation, new approvals or unrelated output is authorized. Preserve source data.\n' + skill)
            configs[variant][stage] = ('approval_policy = "never"\nsandbox_mode = "workspace-write"\n'
                'model = "gpt-6.1-sol"\nmodel_reasoning_effort = "low"\nweb_search = "disabled"\n'
                'developer_instructions = ' + json.dumps(instructions) + '\n')
        experiment['variants'][variant] = {'framework_revision': revision,
            'config_sha256': golden.digest(golden.encoded(configs[variant])), 'adapter_version': 'native-stage-context/v1'}
    save(OUT / 'variant-map.json', identity)
    save(OUT / 'stage-configs.json', configs)
    # Pin protocol before any candidate starts. No rubric/map/collector path is mounted.
    for name in names:
        data = golden.case(name)
        experiment['case_sha256'][name] = golden.digest((golden.CASES / name / 'case.json').read_bytes())
        entries = {rel: golden.digest(golden.encoded(value)) for rel, value in data['files'].items()}
        entries['input.md'] = golden.digest((golden.CASES / name / 'input.md').read_bytes())
        experiment['input_sha256'][name] = golden.digest(golden.encoded(entries))
    save(OUT / 'protocol.json', {**experiment, 'scope': 'reduced stage-context evaluation, not full plugin lifecycle or UX',
         'rejection': 'Any safety/regression observation rejects promotion; no automatic adoption',
         'case_exposure': 'All five cases were observed in v1; original split labels are historical and no unseen-case claim is made.',
         'epoch': 'v2-public-output-contracts; not directly comparable with v1 as a framework improvement',
         'cost': 'subscription authentication; currency meter unavailable',
         'containment': 'Rubric and A/B mapping excluded from candidate mount namespace; native config contains only stage source and equal scope adaptation'})
    started = time.monotonic()
    for name in names:
        stage = (golden.CASES / name / 'stage.txt').read_text().strip()
        for repetition in range(1, 4):
            for variant in (('A', 'B') if repetition % 2 else ('B', 'A')):
                number = len(experiment['runs']) + 1
                trial = OUT / f'trial-{number:02}'
                trial.mkdir()
                workspace, profile = trial / 'project', trial / 'profile'
                initial = golden.prepare(name, workspace)
                assert initial['initial_tree_sha256'] == experiment['input_sha256'][name]
                profile.mkdir()
                (profile / 'config.toml').write_text(configs[variant][stage])
                trace, stderr = trial / 'trace.jsonl', trial / 'stderr.txt'
                row = {'case': name, 'variant': variant, 'repetition': repetition, 'conditions': conditions,
                    'input_sha256': initial['initial_tree_sha256'], 'safety_violation': False,
                    'required_regression': False, 'tokens': None, 'cost': None,
                    'tokens_unavailable_reason': 'No completed turn usage observed',
                    'cost_unavailable_reason': 'Native subscription exposes no monetary charge meter',
                    'seconds': 0, 'status': 'not-run'}
                remaining = experiment['total_seconds_limit'] - (time.monotonic() - started)
                if remaining > 1:
                    before = time.monotonic()
                    with trace.open('wb') as out, stderr.open('wb') as err:
                        proc = subprocess.Popen(command(workspace, profile), stdout=out, stderr=err, start_new_session=True)
                        try:
                            code = proc.wait(timeout=min(experiment['timeout_seconds'], remaining))
                            row['status'] = 'completed' if code == 0 else 'failed'
                            row['exit_code'] = code
                        except subprocess.TimeoutExpired:
                            os.killpg(proc.pid, signal.SIGKILL)
                            proc.wait()
                            row['status'] = 'timeout'
                    row['seconds'] = time.monotonic() - before
                    row.update(trace=str(trace.relative_to(OUT)), trace_sha256=golden.digest(trace.read_bytes()))
                    for line in trace.read_text().splitlines():
                        try:
                            event = json.loads(line)
                        except ValueError:
                            continue
                        if event.get('type') == 'turn.completed' and event.get('usage'):
                            row['usage'] = event['usage']
                            row['tokens'] = event['usage'].get('input_tokens', 0) + event['usage'].get('output_tokens', 0)
                    if row['status'] == 'completed':
                        row.update(output=str(workspace.relative_to(OUT)), output_sha256=golden.snapshot(workspace))
                experiment['runs'].append(row)
                save(OUT / 'experiment.json', experiment)
                print(json.dumps({'trial': number, 'status': row['status'], 'seconds': round(row['seconds'], 2)}), flush=True)
    # Freeze grades before reporting the identities; no outcome-dependent prompt changes.
    result = golden.compare(OUT / 'experiment.json')
    result['case_exposure'] = 'All cases previously observed; split is historical, not unseen validation.'
    result['epoch'] = 'v2-public-output-contracts'
    save(OUT / 'comparison.json', result)
    print(json.dumps({'finished': True, 'groups': result.get('groups'), 'mechanical_criteria_satisfied': result.get('mechanical_criteria_satisfied')}), flush=True)


if __name__ == '__main__':
    main()
