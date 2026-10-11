#!/usr/bin/env python3
"""Shared Claude spec/impl transport; canonical validators own admission."""
import argparse
import importlib.util
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys

spec = importlib.util.spec_from_file_location(
    'transport', Path(__file__).with_name('validate-nontty-spec-launch.py'))
if spec is None or spec.loader is None:
    raise ValueError('transport loader unavailable')
transport = importlib.util.module_from_spec(spec)
spec.loader.exec_module(transport)


def run(root, command, destination, prompt=None):
    result = subprocess.run(command, cwd=root, input=prompt, text=True,
                            capture_output=True, timeout=600)
    destination.write_text(result.stdout)
    destination.with_suffix(destination.suffix + '.stderr').write_text(result.stderr)
    transport.require(result.returncode == 0, 'command failed; see ' + str(destination))
    return result.stdout


def required_dependencies(root, data):
    """Require canonical conditional inputs before any reservation."""
    if data['stage'] == 'task':
        return {'inputs': []}
    helper_spec = importlib.util.spec_from_file_location(
        'conditional_inputs', Path(__file__).parents[2] /
        'sdd-quality-loop/scripts/review-conditional-inputs.py')
    if helper_spec is None or helper_spec.loader is None:
        raise ValueError('conditional input loader unavailable')
    helper = importlib.util.module_from_spec(helper_spec)
    helper_spec.loader.exec_module(helper)
    result = helper.resolve(root, data['feature'], data['stage'])
    admitted = {entry['path']: entry.get('sha256')
                for entry in data['allowed_input_manifest']}
    for entry in result['inputs']:
        transport.require(admitted.get(entry['path']) == entry['sha256'],
                          'conditional input missing or stale: ' + entry['path'])
    return result


def checked_input_paths(root, data):
    """Reject unsafe manifest paths before opening any caller-named input."""
    entries = data['allowed_input_manifest']
    transport.require(isinstance(entries, list) and entries, 'input manifest is empty')
    seen = set()
    for entry in entries:
        transport.require(isinstance(entry, dict) and set(entry) == {'path', 'sha256'},
                          'invalid input manifest entry')
        path, digest = entry['path'], entry['sha256']
        transport.require(isinstance(path, str) and
                          re.fullmatch(r'[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*', path) and
                          all(part not in ('.', '..') for part in path.split('/')) and
                          not re.match(r'^[A-Za-z]:', path) and
                          isinstance(digest, str) and re.fullmatch(r'[0-9a-f]{64}', digest) and
                          path not in seen, 'unsafe or duplicate input manifest path')
        seen.add(path)
        current = root
        for part in path.split('/'):
            transport.require(current.is_dir(), 'input path parent is not a directory: ' + path)
            transport.require(part in {item.name for item in current.iterdir()},
                              'input path has a case alias: ' + path)
            current = current / part
            transport.require(not current.is_symlink(), 'input path traverses a symlink: ' + path)
        transport.require(current.is_file(), 'input path is not a regular file: ' + path)
    return seen


def verify_inputs_before_output(root, stage, feature, attempt, round_number, runtime='bash'):
    """Use the existing precheck's ADR/design binding before trusting its paths."""
    transport.require(runtime in ('bash', 'powershell'), 'unsupported precheck runtime')
    script = root / 'plugins/sdd-review-loop/scripts' / (stage + '-review-precheck.' +
                                                        ('sh' if runtime == 'bash' else 'ps1'))
    command = (['rtk', 'proxy', 'bash', str(script), feature, str(attempt),
                str(round_number), '--verify-inputs'] if runtime == 'bash' else
               ['rtk', 'proxy', 'pwsh', '-NoProfile', '-File', str(script),
                '-Feature', feature, '-Attempt', str(attempt), '-Round',
                str(round_number), '-VerifyInputs'])
    result = subprocess.run(command,
                            cwd=root, capture_output=True, text=True, timeout=600)
    transport.require(result.returncode == 0, 'read-only precheck failed before output')


def required_input_paths(root, data, precheck_path, attempt, round_number):
    """Rebuild the stage/role set already required by the review prechecks."""
    precheck = transport.load(precheck_path)
    stage, role, feature = data['stage'], data['role'], data['feature']
    transport.require(precheck.get('schema') == stage + '-review-precheck/v1' and
                      precheck.get('feature') == feature and
                      type(precheck.get('attempt')) is int and precheck['attempt'] == attempt and
                      type(precheck.get('round')) is int and precheck['round'] == round_number,
                      'precheck identity differs from invocation')
    spec_dir = 'specs/' + feature + '/'
    round_dir = 'reports/' + stage + '-review/' + feature + '/attempt-' + str(attempt) + '/round-' + str(round_number) + '/'
    calibration = ('spec-review-calibration.md' if stage == 'spec' else 'reviewer-calibration.md')
    expected = {spec_dir + name for name in ('requirements.md', 'acceptance-tests.md')}
    expected.update(('plugins/sdd-review-loop/references/' + calibration,
                     round_dir + 'precheck-result.json'))
    if stage == 'spec':
        if precheck.get('investigation_sha256') is not None:
            expected.add(spec_dir + 'investigation.md')
    elif stage == 'task':
        expected.update(spec_dir + name for name in (
            'design.md', 'tasks.md', 'traceability.md', 'ux-spec.md',
            'frontend-spec.md', 'infra-spec.md', 'security-spec.md'))
        if role == 'task-reviewer-a':
            expected.add(round_dir + 'dependency-graph.json')
        else:
            expected.update('plugins/sdd-quality-loop/references/' + name for name in (
                'risk-gate-matrix.md', 'risk-classification-policy.md'))
    else:
        expected.add(spec_dir + 'design.md')
        if (root / (spec_dir + 'investigation.md')).exists():
            expected.add(spec_dir + 'investigation.md')
        layers = precheck.get('layer_sha256') or {}
        transport.require(isinstance(layers, dict) and
                          set(layers) <= {'ux-spec.md', 'frontend-spec.md', 'infra-spec.md', 'security-spec.md'},
                          'invalid precheck layer paths')
        expected.update(spec_dir + name for name in layers)
        adr = precheck.get('adr_inputs', [])
        transport.require(isinstance(adr, list) and all(isinstance(e, dict) and
                          set(e) == {'path', 'sha256'} and
                          isinstance(e['path'], str) and
                          re.fullmatch(r'docs/adr/[0-9]{4}-[a-z0-9][a-z0-9-]*\.md', e['path']) and
                          isinstance(e['sha256'], str) and
                          re.fullmatch(r'[0-9a-f]{64}', e['sha256']) for e in adr) and
                          [e['path'] for e in adr] == sorted({e['path'] for e in adr}),
                          'invalid precheck ADR paths')
        expected.update(e['path'] for e in adr)
        if role == 'impl-reviewer-a' and round_number > 1:
            expected.add('reports/impl-review/' + feature + '/attempt-' + str(attempt) +
                         '/round-' + str(round_number - 1) + '/integrated-summary.json')
    if role.endswith('-b'):
        expected.add(round_dir + 'integrated-summary.json')
    expected.update(e['path'] for e in required_dependencies(root, data)['inputs'])
    return expected


def quality_input_precheck(root, invocation, output, data):
    """Run canonical quality admission and native preflight before any output."""
    session = data['host_session_id']
    transport.require(output.resolve().parent ==
                      (root / 'reports/quality-gate').resolve() and
                      output.name == 'launch-' + session and
                      not output.exists() and not output.is_symlink(),
                      'quality output must be a fresh quality-gate/session directory')
    feature = data['feature']
    task_id = data['task_id']
    required = {'specs/' + feature + '/' + name for name in (
        'requirements.md', 'design.md', 'acceptance-tests.md',
        'tasks.md', 'traceability.md')}
    required.add('plugins/sdd-quality-loop/references/quality-gate-calibration.md')
    required.add('reports/implementation/' + feature + '/' + task_id + '.md')
    admitted = {entry['path'] for entry in data['allowed_input_manifest']}
    transport.require(required <= admitted,
                      'quality invocation omits required specification, calibration, or task report')
    checked_input_paths(root, data)
    validator = root / 'plugins/sdd-quality-loop/scripts/validate-review-context-set.sh'
    check = ['rtk', 'proxy', 'bash', str(validator), str(invocation), str(root)]
    result = subprocess.run(check, cwd=root, text=True, capture_output=True,
                            timeout=600)
    transport.require(result.returncode == 0 and
                      re.fullmatch(r'REVIEW_CONTEXT_OK [0-9a-f]{64} sequence=[1-9][0-9]* '
                                   r'previous_record_sha256=(?:-|[0-9a-f]{64}) '
                                   r'pre_append_tip_sequence=[0-9]+ identity_unique=yes\n?',
                                   result.stdout) is not None,
                      'canonical quality input preview failed before reservation')
    preflight = transport.preflight(root, invocation, output / (session + '.jsonl'))
    transport.require(preflight.get('status') == 'PREFLIGHT_OK' and
                      preflight.get('session_id') == session and
                      preflight.get('invocation_sha256') == transport.sha(invocation),
                      'quality preflight does not bind this invocation')
    return result.stdout


def quality_delivery_command(root, invocation, pin, data):
    return ['rtk', 'proxy', sys.executable, '-B',
            str(root / 'plugins/sdd-quality-loop/scripts/preflight-evaluator-delivery.py'),
            '--manifest', str(invocation), '--manifest-sha256', pin,
            '--repository-root', str(root), '--scratch-root', data['scratch_root']]


def quality_delivery_result(text, count, *, reserved=False):
    summary = ('EVALUATOR_DELIVERY_OK inputs=' + str(count) + '; reservation=' +
               ('performed' if reserved else 'not performed') + '\n')
    if not reserved:
        transport.require(text == summary, 'invalid evaluator delivery preflight result')
        return None
    transport.require(text.endswith(summary), 'invalid evaluator reservation delivery result')
    receipt = text[:-len(summary)]
    transport.require(re.fullmatch(
        r'REVIEW_CONTEXT_OK [0-9a-f]{64} sequence=[1-9][0-9]* '
        r'previous_record_sha256=(?:-|[0-9a-f]{64}) '
        r'pre_append_tip_sequence=[0-9]+ identity_unique=yes\n', receipt) is not None,
        'incomplete evaluator reservation receipt')
    return receipt


def launch(root, invocation, output, manifest_sha256=None):
    root = root.resolve()
    transport.require(invocation.is_file() and not invocation.is_symlink(),
                      'invocation is not a regular file')
    invocation = invocation.resolve(strict=True)
    if manifest_sha256 is not None:
        transport.require(re.fullmatch(r'[0-9a-f]{64}', manifest_sha256) is not None and
                          transport.sha(invocation) == manifest_sha256,
                          'caller invocation pin mismatch')
    data, _ = transport.manifest(root, invocation)
    stage = data['stage']
    transport.require(stage in ('spec', 'impl', 'task', 'quality'), 'unsupported review stage')
    transport.require(stage != 'quality' or manifest_sha256 is not None,
                      'quality launch requires an external caller manifest pin')
    feature = data.get('feature', '')
    transport.require(re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', feature), 'unsafe feature')
    session = data['host_session_id']
    scripts = root / 'plugins/sdd-review-loop/scripts'
    validator = root / 'plugins/sdd-quality-loop/scripts/validate-review-context-set.sh'
    probe = scripts / 'probe-nontty-review.py'
    check = ['rtk', 'proxy', 'bash', str(validator), str(invocation), str(root)]
    input_preflight = subprocess.run(
        ['rtk', 'proxy', sys.executable, str(scripts / 'preflight-host-review.py'),
         str(root), str(invocation), '--manifest-sha256', transport.sha(invocation)],
        cwd=root, capture_output=True, text=True, timeout=600)
    transport.require(input_preflight.returncode == 0,
                      'common input preflight rejected: ' + input_preflight.stderr.strip())
    transport.require(re.fullmatch(
        r'HOST_REVIEW_PREFLIGHT_OK inputs=[1-9][0-9]* '
        r'permission-proof=not-established reservation=not-performed\n?',
        input_preflight.stdout) is not None, 'invalid common input preflight result')
    if stage == 'quality':
        delivery = quality_delivery_command(root, invocation, manifest_sha256, data)
        prepared = subprocess.run(delivery, cwd=root, capture_output=True, text=True, timeout=600)
        transport.require(prepared.returncode == 0,
                          'evaluator delivery preflight rejected: ' + prepared.stderr.strip())
        quality_delivery_result(prepared.stdout, len(data['allowed_input_manifest']))
        initial_preview = quality_input_precheck(root, invocation, output, data)
        round_dir = root / 'reports/quality-gate'
        role_path = root / 'plugins/sdd-quality-loop/agents/evaluator.md'
        verify = None
        dependency_presence = None
    else:
        pattern = re.compile(r'reports/' + stage + r'-review/' + re.escape(feature) +
                             r'/attempt-([1-9][0-9]*)/round-([1-9][0-9]*)/precheck-result.json')
        matches = [pattern.fullmatch(e['path']) for e in data['allowed_input_manifest']]
        rounds = [m for m in matches if m is not None]
        transport.require(len(rounds) == 1, 'one admitted precheck is required')
        attempt, round_number = rounds[0].groups()
        admitted = checked_input_paths(root, data)
        precheck_path = root / rounds[0].group()
        precheck_digest = transport.sha(precheck_path)
        verify_inputs_before_output(root, stage, feature, int(attempt), int(round_number))
        expected = required_input_paths(root, data, precheck_path,
                                        int(attempt), int(round_number))
        transport.require(transport.sha(precheck_path) == precheck_digest,
                          'precheck changed during early input validation')
        transport.require(admitted == expected,
                          'input manifest differs from required stage/role set: missing=' +
                          repr(sorted(expected - admitted)) + ' extra=' + repr(sorted(admitted - expected)))
        round_dir = root / Path(rounds[0].group()).parent
        transport.require(output.resolve().parent == round_dir.resolve() and
                          output.name == 'launch-' + session,
                          'output must be a fresh round/session directory')
        role_path = root / ('plugins/sdd-review-loop/agents/' + data['role'] + '.md')
        verify = ['rtk', 'proxy', 'bash', str(scripts / (stage + '-review-precheck.sh')),
                  feature, attempt, round_number, '--verify-inputs']
        dependency_presence = required_dependencies(root, data)
    role_parts = role_path.read_text().split('---', 2)
    transport.require(len(role_parts) == 3 and not role_parts[0].strip(),
                      'role frontmatter missing')
    selected_model = 'sonnet'
    if stage == 'quality':
        model_line = re.findall(r'^model: ([A-Za-z0-9_-]+)$', role_parts[1], re.MULTILINE)
        transport.require(len(model_line) == 1, 'role model missing or ambiguous')
        selected_model = model_line[0]
    transport.require(selected_model == 'sonnet',
                      'role model conflicts with Sonnet-only launch authorization')
    # Exclusive creation prevents an interrupted launch from replaying reservation.
    output.mkdir()
    transcript = output / (session + '.jsonl')
    preflight_result = transport.preflight(root, invocation, transcript)
    transport.require(preflight_result.get('status') == 'PREFLIGHT_OK' and
                      preflight_result.get('session_id') == session and
                      preflight_result.get('invocation_sha256') == transport.sha(invocation),
                      'non-TTY preflight result does not bind this invocation')
    if stage != 'quality':
        short_role = data['role'].rsplit('-', 1)[-1]
        preflight_path = round_dir / ('reviewer-' + short_role + '-nontty-preflight.json')
        allocation_path = round_dir / ('reviewer-' + short_role + '-host-allocation.json')
        transport.require(not preflight_path.exists() and not preflight_path.is_symlink() and
                          not allocation_path.exists() and not allocation_path.is_symlink(),
                          'round already has preflight or allocation evidence')
        with preflight_path.open('xb') as record:
            record.write(json.dumps(preflight_result, sort_keys=True).encode())
        proposal = {
            'kind': 'claude-nontty-caller-proposal',
            'host_id': session, 'host_session_id': session,
            'role': data['role'], 'feature': feature,
            'attempt': int(attempt), 'round': int(round_number),
            'review_turn_started': False,
            'preflight_result_path': preflight_path.relative_to(root).as_posix(),
            'preflight_result_sha256': transport.sha(preflight_path),
            'preflight_result': preflight_result['status'],
        }
        proposal_bytes = json.dumps(proposal, sort_keys=True).encode()
        with allocation_path.open('xb') as record:
            record.write(proposal_bytes)
        with (output / 'caller-proposal.json').open('xb') as record:
            record.write(proposal_bytes)
    role = {'description': 'Repository-bound independent implementation reviewer',
            'prompt': role_parts[2].strip(), 'model': selected_model,
            'tools': transport.agent_tools(stage),
            'disallowedTools': ['Grep', 'Glob', 'Write', 'Edit', 'NotebookEdit']}
    # Pin current dependencies, not just the caller's manifest. No baseline promotion.
    files = {invocation, role_path, probe}
    for folder in ('plugins/sdd-review-loop', 'plugins/sdd-quality-loop'):
        files.update(p for p in (root / folder).rglob('*') if p.is_file())
    files.update(root / e['path'] for e in data['allowed_input_manifest'])
    for name in ('rtk', 'claude', 'node', 'bash', 'jq', 'shasum'):
        executable = shutil.which(name)
        if executable is None:
            raise ValueError('missing dependency: ' + name)
        files.add(Path(executable).resolve(strict=True))
    pins = {str(p): transport.sha(p) for p in files}
    (output / 'dependencies.json').write_text(json.dumps(pins, sort_keys=True))
    if verify is not None:
        run(root, verify, output / 'verify-before.txt')
    preview = run(root, check, output / 'preview.txt')
    if stage == 'quality':
        transport.require(preview == initial_preview,
                          'quality admission changed after initial preview')
    receipt = output / 'receipt.txt'
    receipt.write_text(preview)
    policy = output / 'policy.json'
    settings = output / 'settings.json'
    policy_bytes, settings_value = transport.launch_policy(root, invocation, receipt, policy)
    policy.write_bytes(policy_bytes)
    settings.write_text(json.dumps(settings_value))
    permissions = transport.receipt_control(
        data, preview, invocation.relative_to(root).as_posix(), root=root)['exact_permission_rules']
    command = transport.claude_command(root, session, data['role'], role, permissions,
                                       settings, invocation, receipt, policy)
    native = run(root, ['rtk', 'proxy', sys.executable, '-B', str(probe), str(invocation)], output / 'native.jsonl')
    proof = json.loads(native.strip().splitlines()[-1])
    transport.require(proof.get('admitted_read_executed') is True and
                      proof.get('outside_read_pretool_denied') is True and
                      proof.get('chained_bash_pretool_denied') is True and
                      proof.get('existing_session_collision_rejected') is True and
                      proof.get('control_reads_executed') is True and
                      proof.get('source_invocation_read_executed') is True and
                      proof.get('ordered_hashes_verified') == len(data['allowed_input_manifest']) + 5 and
                      proof.get('source_invocation_sha256') == pins[str(invocation)] and
                      proof.get('admitted_paths') == [e['path'] for e in data['allowed_input_manifest']],
                      'native permission proof incomplete or for different inputs')
    if stage != 'quality':
        transport.require(required_dependencies(root, data) == dependency_presence,
                          'conditional dependency presence changed')
    transport.require(all(transport.sha(Path(p)) == digest for p, digest in pins.items()),
                      'dependency changed during native preflight')
    transport.preflight(root, invocation, transcript)
    if verify is not None:
        run(root, verify, output / 'verify-after.txt')
    transport.require(run(root, check, output / 'preview-after.txt') == preview,
                      'admission changed during native preflight')
    transport.require(transport.claude_command(root, session, data['role'], role, permissions,
                      settings, invocation, receipt, policy) == command, 'launch argv changed')
    if stage == 'quality':
        reserved = quality_delivery_result(
            run(root, delivery + ['--reserve'], output / 'reserved.txt'),
            len(data['allowed_input_manifest']), reserved=True)
    else:
        reserved = run(root, check + ['--reserve'], output / 'reserved.txt')
    transport.require(reserved == preview, 'reservation differs from preview; do not retry identity')
    receipt.write_text(reserved)
    prompt = output / 'prompt.txt'
    prompt.write_bytes(transport.expected_prompt(root, invocation, receipt, strict=True,
                                                 conditional_state=dependency_presence))
    wrapper = output / 'wrapper.json'
    run(root, command, wrapper, prompt.read_text())
    transcripts = list((Path.home() / '.claude/projects').rglob(session + '.jsonl'))
    transport.require(len(transcripts) == 1, 'native transcript missing or ambiguous')
    transcript.write_bytes(transcripts[0].read_bytes())
    result = transport.postflight(root, invocation, transcript, prompt, wrapper, receipt,
                                  strict=True, conditional_state=dependency_presence)
    (output / 'delivery.json').write_text(json.dumps(result, sort_keys=True))
    # Delivery is not a verdict. Existing canonical output validation/adoption follows.
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('invocation', type=Path)
    parser.add_argument('output', type=Path)
    parser.add_argument('--manifest-sha256', help='external caller pin; required for quality')
    args = parser.parse_args()
    try:
        print(json.dumps(launch(args.root, args.invocation, args.output,
                                args.manifest_sha256), sort_keys=True))
    except (ValueError, OSError, KeyError, TypeError, subprocess.TimeoutExpired) as error:
        print('LAUNCH_STOPPED: ' + str(error), file=sys.stderr)
        sys.exit(1)
