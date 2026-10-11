#!/usr/bin/env python3
"""Read-only spec/impl proof for caller-proposed non-TTY Claude IDs.

This does not reserve an identity or approve a review verdict. The normal
review-context validator still owns reservation and output schema checks.
"""
import argparse
import hashlib
import json
import pathlib
import re
import shlex
import shutil
import subprocess
import sys
import uuid
from typing import Any


STAGE_ROLES = {
    'spec': ('spec-reviewer-a', 'spec-reviewer-b'),
    'impl': ('impl-reviewer-a', 'impl-reviewer-b'),
    'task': ('task-reviewer-a', 'task-reviewer-b'),
    'quality': ('sdd-evaluator',),
}
JSON_REVIEW_STAGES = ('spec', 'impl', 'task')
STRUCTURED_OUTPUT_ENFORCE_TURN = ('[structured-output-enforce] You MUST call the '
                                  'StructuredOutput tool to complete this request. '
                                  'Call this tool now.')


def admitted_raw_hashes(root, data):
    """Keep raw transport observations separate from canonical task normalization."""
    entries = data['allowed_input_manifest']
    actual = {e['path']: sha(root / e['path']) for e in entries}
    mismatches = [e for e in entries if actual[e['path']] != e['sha256']]
    if mismatches:
        feature = data.get('feature', '')
        require(data['stage'] == 'task' and len(mismatches) == 1 and
                mismatches[0]['path'] == 'specs/' + feature + '/tasks.md',
                'admitted input hash mismatch')
        pattern = re.compile(r'reports/task-review/' + re.escape(feature) +
                             r'/attempt-([1-9][0-9]*)/round-([1-9][0-9]*)/precheck-result.json')
        matches = [(e, match) for e in entries
                   if (match := pattern.fullmatch(e['path'])) is not None]
        require(len(matches) == 1, 'task precheck missing or duplicated')
        entry, match = matches[0]
        precheck = load(root / entry['path'])
        require(actual[entry['path']] == entry['sha256'] and
                precheck.get('schema') == 'task-review-precheck/v1' and
                precheck.get('feature') == feature and
                precheck.get('attempt') == int(match[1]) and
                precheck.get('round') == int(match[2]) and
                precheck.get('tasks_sha256_form') == 'normalized' and
                precheck.get('tasks_sha256') == mismatches[0]['sha256'],
                'normalized task input is not precheck-bound')
        result = subprocess.run(['rtk', 'proxy', 'bash', str(root /
            'plugins/sdd-review-loop/scripts/task-review-precheck.sh'), feature,
            match[1], match[2], '--verify-inputs'], cwd=root,
            text=True, capture_output=True, timeout=600)
        require(result.returncode == 0, 'canonical normalized task verification failed')
        require(all(sha(root / e['path']) == actual[e['path']] for e in entries),
                'inputs changed during normalized task verification')
    return actual


def review_output_schema(stage, role):
    """Constrain transport types; canonical validators still own completeness.

    Fields are optional so the same argv supports a diagnostic without inventing
    review findings or a verdict. Formal adoption must still validate the result.
    """
    text = {'type': 'string'}
    entries = {'type': 'array', 'items': {'type': 'object', 'properties': {
        'path': text, 'sha256': text}, 'required': ['path', 'sha256']}}
    check_fields = {key: text for key in ('id', 'result', 'status', 'severity', 'finding')}
    properties: dict[str, Any] = {key: text for key in ('schema', 'stage', 'role', 'run_id',
                                       'host_session_id', 'verdict')}
    properties['checks'] = {'type': 'array', 'items': {
        'type': 'object', 'properties': check_fields}}
    if stage == 'task':
        properties.update(feature=text, attempt={'type': 'integer'}, round={'type': 'integer'},
                          manifest=entries if role == 'task-reviewer-a' else {
                              'type': 'object', 'properties': {'allowed_inputs': entries},
                              'required': ['allowed_inputs']},
                          findings={'type': 'array', 'items': {'type': 'object', 'properties': {
                              'check_id': text, 'severity': text, 'finding': text,
                              'task_id': {'type': ['string', 'null']}}}})
    else:
        properties['allowed_input_manifest'] = entries
        if role == 'impl-reviewer-a':
            properties.update(legacy_design={'type': 'boolean'}, feature_type=text)
    return {'type': 'object', 'properties': properties}


def claude_command(root, session, role_name, role, permissions, settings_path,
                   invocation, receipt, policy_path):
    """One argv builder for the unreserved diagnostic and formal transport."""
    identity(session)
    data, _ = manifest(root, invocation)
    selected_model = role.get('model')
    require(selected_model == 'sonnet' and
            role.get('tools') == agent_tools(data['stage']) and
            role.get('disallowedTools') == ['Grep', 'Glob', 'Write', 'Edit', 'NotebookEdit'] and
            isinstance(selected_model, str), 'unsupported role permission profile')
    require(data['host_session_id'] == session, 'session differs from invocation')
    policy_bytes, expected_settings = launch_policy(root, invocation, receipt, policy_path)
    require(policy_path.read_bytes() == policy_bytes and load(settings_path) == expected_settings,
            'session guard settings or policy mismatch')
    relative = invocation.relative_to(root).as_posix()
    require(permissions == receipt_control(data, receipt.read_text(), relative, root=root)['exact_permission_rules'],
            'permission rules mismatch')
    admitted_raw_hashes(root, data)
    require((root / 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs').is_file(),
            'session guard missing')
    executable = shutil.which('claude')
    if executable is None:
        raise ValueError('Claude executable missing')
    command = ['rtk', 'proxy', executable, '-p', '--session-id', session,
               '--model', selected_model, '--permission-mode', 'dontAsk',
               '--tools', 'Read,Bash', '--disallowedTools',
               'Grep,Glob,Write,Edit,NotebookEdit',
               '--settings', str(settings_path), '--plugin-dir',
               str(root / 'plugins/sdd-review-loop'), '--agents',
               json.dumps({role_name: role}), '--agent', role_name, '--output-format', 'json']
    if data['stage'] in JSON_REVIEW_STAGES:
        command += ['--json-schema', json.dumps(review_output_schema(data['stage'], role_name))]
    help_result = subprocess.run(['rtk', 'proxy', executable, '--help'],
                                 capture_output=True, text=True, cwd=root, timeout=30)
    require(help_result.returncode == 0, 'Claude help failed')
    declarations = '\n'.join(line.split('  ', 1)[0] for line in
                             (line.strip() for line in help_result.stdout.splitlines())
                             if line.startswith('-'))
    for flag in ('-p', '--session-id', '--model', '--permission-mode', '--tools',
                 '--disallowedTools', '--settings', '--plugin-dir',
                 '--agents', '--agent', '--output-format',
                 *(['--json-schema'] if data['stage'] in JSON_REVIEW_STAGES else [])):
        require(re.search(r'(?<![\w-])' + re.escape(flag) + r'(?=[\s,=<\[]|$)', declarations) is not None,
                'unsupported CLI argument: ' + flag)
    return command


def agent_tools(stage):
    """StructuredOutput is output-only for JSON review stages."""
    return ['Read', 'Bash', 'StructuredOutput'] if stage in JSON_REVIEW_STAGES else ['Read', 'Bash']


def require_probe_tool_sequence(actual, expected, stage):
    final = [('StructuredOutput', None)] if stage in JSON_REVIEW_STAGES else []
    require(actual == expected + final, 'native probe tool sequence differs')


def require(ok, message):
    if not ok:
        raise ValueError(message)


def load(path):
    def unique(pairs):
        result = {}
        for key, value in pairs:
            require(key not in result, 'duplicate JSON key')
            result[key] = value
        return result
    return json.loads(path.read_bytes(), object_pairs_hook=unique)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def identity(value):
    require(isinstance(value, str), 'session identity missing')
    try:
        parsed = uuid.UUID(value)
    except ValueError as error:
        raise ValueError('proposed session is not UUID') from error
    require(parsed.version == 4 and str(parsed) == value, 'proposed session must be canonical UUIDv4')


def manifest(root, path):
    data = load(path)
    stage = data.get('stage')
    require(data.get('schema') == 'review-context-invocation/v2' and
            stage in STAGE_ROLES and
            data.get('role') in STAGE_ROLES.get(stage, ()) and
            data.get('read_only') is True and
            data.get('input_mode') == 'file-manifest' and
            data.get('fallback_mode') == 'none', 'not a read-only spec/impl invocation')
    if stage == 'quality':
        require(re.fullmatch(r'T-[0-9]{3}', data.get('task_id', '')) is not None and
                isinstance(data.get('scratch_root'), str) and
                pathlib.Path(data['scratch_root']).is_absolute(),
                'quality task identity or evaluator scratch root missing')
    session = data.get('host_session_id')
    identity(session)
    require(data.get('run_id') == session,
            'non-TTY adapter must alias run_id to the one proposed session UUID')
    ledger_rel = data.get('identity_ledger_path')
    require(ledger_rel == 'reports/review-context/identity-ledger.json',
            'unexpected ledger path')
    ledger = load(root / ledger_rel)
    require(ledger.get('schema') == 'review-identity-ledger/v1' and
            isinstance(ledger.get('records'), list), 'invalid identity ledger')
    return data, ledger


def preflight(root, invocation, transcript):
    data, ledger = manifest(root, invocation)
    session = data['host_session_id']
    require(not transcript.exists(), 'native session transcript already exists')
    require(transcript.name == session + '.jsonl', 'transcript path does not name proposed session')
    require(not any((pathlib.Path.home() / '.claude/projects').rglob(session + '.jsonl')),
            'proposed identity already has a native transcript')
    require(all(record.get('run_id') != session and record.get('host_session_id') != session
                for record in ledger['records']), 'proposed identity already appears in ledger')
    require(sha(root / data['identity_ledger_path']) == data.get('identity_ledger_sha256'),
            'invocation ledger pin is stale')
    return {'status': 'PREFLIGHT_OK', 'session_id': session,
            'invocation_sha256': sha(invocation)}


BOUNDARY_PATH = 'plugins/sdd-review-loop/references/review-context-boundary.md'


def canonical_read_paths(root, relative_paths):
    """Render tool targets without changing relative manifest or receipt identities."""
    return [str((root / relative).resolve()) for relative in relative_paths]


def diagnostic_read_paths(entries, invocation_path):
    """Native probe samples Read; its separate hash and guard checks cover every input."""
    require(entries and isinstance(invocation_path, str) and invocation_path,
            'diagnostic input paths missing')
    samples = [entries[index]['path'] for index in (0, len(entries) // 2, len(entries) - 1)]
    return list(dict.fromkeys(samples + [invocation_path, BOUNDARY_PATH]))


def file_hash_batch_command(paths):
    require(isinstance(paths, list) and paths and all(isinstance(path, str) and path for path in paths),
            'nonempty ordered hash paths required')
    return 'rtk proxy shasum -a 256 ' + ' '.join(shlex.quote(path) for path in paths)


def require_hash_batch_result(result_text, expected):
    require(isinstance(result_text, str) and isinstance(expected, list) and expected,
            'batch hash result missing')
    lines = result_text[:-1] if result_text.endswith('\n') else result_text
    require(lines == '\n'.join(digest + '  ' + path for path, digest in expected),
            'batch hash result differs from ordered pinned digests')


def safe_compact_path(root, relative):
    require(isinstance(relative, str) and
            re.fullmatch(r'[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*', relative) is not None and
            all(part not in ('.', '..') for part in relative.split('/')),
            'invalid compact verification path')
    path = root / relative
    require(path.is_file() and not any((root / pathlib.Path(*pathlib.Path(relative).parts[:i])).is_symlink()
            for i in range(1, len(pathlib.Path(relative).parts) + 1)),
            'compact verification path missing or symlinked')
    return path


def compact_raw_digest(data, hashes):
    return hashlib.sha256('\n'.join(entry['path'] + '\t' + hashes[entry['path']]
        for entry in data['allowed_input_manifest']).encode()).hexdigest()


def compact_result(control, invocation_hash, boundary_hash, raw_hash, count):
    return json.dumps({'status': 'REVIEW_INPUTS_OK', 'invocation_sha256': invocation_hash,
        'boundary_sha256': boundary_hash, 'raw_inputs_sha256': raw_hash,
        'inputs_sha256': control['inputs_sha256'], 'record_sha256': control['record_sha256'],
        'input_count': count}, sort_keys=True, separators=(',', ':'))


def compact_verify(root, invocation_path, invocation_hash, boundary_hash, raw_hash, receipt_text):
    root = pathlib.Path(root).resolve()
    invocation = safe_compact_path(root, invocation_path)
    require(sha(invocation) == invocation_hash, 'compact invocation hash mismatch')
    data = load(invocation)
    control = receipt_control(data, receipt_text, invocation_path)
    for entry in data['allowed_input_manifest']:
        safe_compact_path(root, entry['path'])
    boundary = safe_compact_path(root, BOUNDARY_PATH)
    require(sha(boundary) == boundary_hash, 'compact boundary hash mismatch')
    hashes = admitted_raw_hashes(root, data)
    require(compact_raw_digest(data, hashes) == raw_hash, 'compact raw input set mismatch')
    require(sha(invocation) == invocation_hash and sha(boundary) == boundary_hash,
            'compact control input changed during verification')
    return compact_result(control, invocation_hash, boundary_hash, raw_hash, len(hashes))


def require_compact_result(result_text, expected):
    require(result_text in (expected, expected + '\n'), 'compact verification result mismatch')


def receipt_control(data, receipt_text, invocation_path=None, *, root=None):
    match = re.fullmatch(
        r'REVIEW_CONTEXT_OK ([0-9a-f]{64}) sequence=([1-9][0-9]*) '
        r'previous_record_sha256=(-|[0-9a-f]{64}) pre_append_tip_sequence=([0-9]+) '
        r'identity_unique=yes\n?', receipt_text)
    if match is None:
        raise ValueError('fresh reservation receipt required')
    digest, sequence, previous, tip = match.groups()
    if (type(data['sequence']) is not int or int(sequence) != data['sequence'] or
            int(sequence) != int(tip) + 1 or previous != data['previous_record_sha256']):
        raise ValueError('receipt chain metadata mismatch')
    entries = data['allowed_input_manifest']
    if not isinstance(entries, list) or not entries:
        raise ValueError('nonempty ordered inputs required')
    paths = set()
    for entry in entries:
        if (not isinstance(entry, dict) or set(entry) != {'path', 'sha256'} or
                not isinstance(entry['path'], str) or not entry['path'] or
                any(c in entry['path'] for c in '\t\r\n\x00') or
                re.fullmatch(r'[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*', entry['path']) is None or
                any(segment in ('.', '..') for segment in entry['path'].split('/')) or
                entry['path'] in paths or not isinstance(entry['sha256'], str) or
                re.fullmatch('[0-9a-f]{64}', entry['sha256']) is None):
            raise ValueError('invalid ordered input entry')
        paths.add(entry['path'])
        if data['stage'] in ('impl', 'task'):
            require(not re.fullmatch(r'reviewer-[ab]\.json', entry['path'].rsplit('/', 1)[-1]),
                    'raw reviewer output is not an impl input')
    inputs_text = '\n'.join(entry['path'] + '\t' + entry['sha256'] for entry in entries)
    inputs_hash = hashlib.sha256(inputs_text.encode('utf-8')).hexdigest()
    fields = [str(data['sequence']), data['stage'], data['role'], data['run_id'],
              data['host_session_id'], previous]
    if any(not isinstance(v, str) or any(c in v for c in '|\r\n\x00') for v in fields):
        raise ValueError('invalid record field')
    if data['stage'] == 'quality':
        scratch_binding = hashlib.sha256((data['feature'] + '\n' +
                                          data['scratch_root']).encode('utf-8')).hexdigest()
        record_text = '|'.join(fields) + '|scratch-declaration-v1|' + scratch_binding
    elif data['stage'] == 'task':
        record_text = '|'.join(fields)
    else:
        record_text = '|'.join(fields) + '|allowed-inputs-v1|' + inputs_hash
    if hashlib.sha256(record_text.encode('utf-8')).hexdigest() != digest:
        raise ValueError('receipt record hash mismatch')
    if root is not None:
        root = pathlib.Path(root).resolve()
        invocation = safe_compact_path(root, invocation_path)
        require(load(invocation) == data, 'compact invocation differs from supplied manifest')
        for entry in entries:
            safe_compact_path(root, entry['path'])
        boundary = safe_compact_path(root, BOUNDARY_PATH)
        source = safe_compact_path(root, 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py')
        raw_hash = compact_raw_digest(data, admitted_raw_hashes(root, data))
        invocation_hash, boundary_hash = sha(invocation), sha(boundary)
        bootstrap = ('import hashlib,pathlib,sys; p=pathlib.Path(sys.argv[1]); b=p.read_bytes(); '
                     'valid=not any(q.is_symlink() for q in (p,*p.parents)) and hashlib.sha256(b).hexdigest()==sys.argv[2]; '
                     'valid or sys.exit("verifier hash mismatch"); '
                     'n={"__name__":"pinned_review_verifier","__file__":str(p)}; '
                     'exec(compile(b,str(p),"exec"),n); '
                     'print(n["compact_verify"](pathlib.Path.cwd(),*sys.argv[3:]))')
        command = 'rtk proxy python3 -B -c ' + shlex.quote(bootstrap) + ' ' + ' '.join(
            shlex.quote(value) for value in (str(source), sha(source), invocation_path,
                invocation_hash, boundary_hash, raw_hash, receipt_text.rstrip('\n')))
        control: dict[str, Any] = {'inputs_text': inputs_text, 'inputs_sha256': inputs_hash,
                   'record_text': record_text, 'record_sha256': digest,
                   'compact_command': command, 'hash_commands': [command],
                   'exact_permission_rules': ['Bash(' + command + ')']}
        control['compact_output'] = compact_result(control, invocation_hash, boundary_hash, raw_hash, len(entries))
        if data['stage'] == 'quality':
            control['scratch_declaration_sha256'] = scratch_binding
        else:
            control['exact_permission_rules'].append('Bash(rtk proxy test -d domain)')
        return control
    if data['stage'] in ('impl', 'task'):
        inputs_format = '\\n'.join('\\t'.join(('%s', '%s')) for _ in entries)
        input_values = ' '.join(shlex.quote(value)
                                for entry in entries
                                for value in (entry['path'], entry['sha256']))
        producers = ["rtk proxy printf '" + inputs_format + "' " + input_values,
                     'rtk proxy printf %s ' + shlex.quote(record_text)]
    else:
        producers = ["printf '%s' " + shlex.quote(text)
                     for text in (inputs_text, record_text)]
    commands = [producer + ' | rtk proxy shasum -a 256' for producer in producers]
    control = {'inputs_text': inputs_text, 'inputs_sha256': inputs_hash,
            'record_text': record_text, 'record_sha256': digest,
            'hash_commands': commands}
    if data['stage'] == 'quality':
        control['scratch_declaration_sha256'] = scratch_binding
    # Claude may check a pipeline as a whole or by its subcommands. The pinned
    # hook still admits only the complete commands above, never a component.
    control['exact_permission_rules'] = [
        'Bash(' + command + ')' for command in commands
    ] + ['Bash(' + producer + ')' for producer in producers] + [
        'Bash(rtk proxy shasum -a 256)']
    if invocation_path is not None:
        require(isinstance(invocation_path, str) and
                re.fullmatch(r'[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*', invocation_path) is not None and
                all(part not in ('.', '..') for part in invocation_path.split('/')),
                'invalid invocation path')
        control['exact_permission_rules'].append('Bash(' + file_hash_batch_command(
            [invocation_path] + [entry['path'] for entry in entries] + [BOUNDARY_PATH]) + ')')
    else:
        # Legacy spec prompts do not enforce a native hash command list.
        control['exact_permission_rules'].append('Bash(' + file_hash_batch_command(
            [entry['path'] for entry in entries] + [BOUNDARY_PATH]) + ')')
    if data['stage'] != 'quality':
        control['exact_permission_rules'].append('Bash(rtk proxy test -d domain)')
    return control


def control_prompt(data, receipt_text, boundary_sha256, *, strict=False,
                   invocation_path=None, invocation_sha256=None, root=None):
    control = receipt_control(data, receipt_text, invocation_path, root=root)
    enforced = data['stage'] in ('impl', 'task', 'quality') or strict
    if enforced:
        require(invocation_path is not None and
                isinstance(invocation_sha256, str) and
                re.fullmatch(r'[0-9a-f]{64}', invocation_sha256) is not None,
                'invocation raw hash missing')
    if 'compact_command' in control:
        return ('Launch-control: execute this exact source-hash-pinned verifier before any substantive Read. '
                'It checks every admitted input, invocation, boundary, ordered receipt and raw input binding.\n'
                '```sh\n' + control['compact_command'] + '\n```\n'
                'Require exactly this result (one trailing newline allowed):\n' + control['compact_output'] + '\n'
                'Wait for and check the result before any other tool call. A routine first-Bash fact-forcing '
                'refusal allows one immediate identical-command retry after the requested facts; any other '
                'failure stops without a verdict. Never inspect the ledger or reserve again.\n')
    if not enforced:
        # Preserve the historical spec prompt byte-for-byte.
        del control['exact_permission_rules']
    control['boundary_path'] = BOUNDARY_PATH
    control['boundary_sha256'] = boundary_sha256
    retry_note = (
        'A routine first-Bash fact-forcing refusal may be retried once with identical command '
        'bytes after providing the required facts; it is not a review or session retry. '
        'Any other refusal or changed command stops without a verdict. '
        if enforced else '')
    order_note = (
        'Hash the invocation, every admitted file in manifest order, and the boundary document in '
        'one exact shasum command. Match every printed path and raw digest in that same order; reject '
        'missing, extra, reordered or mismatched lines. Wait for this first Bash result and verify all '
        'lines before issuing another tool call. Then hash ordered inputs and the receipt record '
        'serially, waiting for and checking each result. Complete every hash before substantive Read. '
        if enforced else '')
    ordered_commands = (
        [file_hash_batch_command([invocation_path] +
                                 [entry['path'] for entry in data['allowed_input_manifest']] +
                                 [BOUNDARY_PATH])]
        + control['hash_commands'] if enforced else [])
    command_note = (
        'Execute these exact commands in numbered issue order '
        'below. Preserve literal TAB/LF characters inside quotes; '
        'do not copy JSON escape sequences into Bash.\n'
        + ''.join(str(index) + '.\n```sh\n' + command + '\n```\n'
                  for index, command in enumerate(ordered_commands, 1))
        if enforced else '')
    return (
        'Launch-control input (not peer evidence): read and hash the boundary document below.\n'
        + ('Invocation raw SHA-256: ' + invocation_sha256 + '\n' if enforced else '')
        + json.dumps(control, ensure_ascii=True, sort_keys=True) + '\n'
        + command_note
        + 'Independently reconstruct inputs_text from the ordered invocation entries as path TAB sha256 '
        'joined with LF, no terminal newline. Hash its exact UTF-8 bytes. Reconstruct record_text as '
        'sequence|stage|role|run_id|host_session_id|previous_record_sha256 followed by '
        + ('|scratch-declaration-v1| and SHA-256 of feature LF scratch_root (no terminal newline). '
           if data['stage'] == 'quality' else
           'nothing else; the canonical task ledger uses the six-field record. '
           if data['stage'] == 'task' else '|allowed-inputs-v1| and that input digest. ')
        + 'Hash its exact UTF-8 bytes. '
        'Use the two literal no-newline hash commands only after checking their text against this '
        'independent reconstruction. Caller-provided digests alone are not reviewer proof. '
        + order_note
        + retry_note
        + 'Require equality to the quoted receipt and sequence=tip+1, previous link equality and '
        'identity_unique=yes before reviewing substantive inputs. If any operation cannot be '
        'performed, stop without a verdict. Never inspect the ledger or reserve again.\n')


def launch_policy(root, invocation, receipt, policy_path):
    data, _ = manifest(root, invocation)
    invocation_relative = invocation.relative_to(root).as_posix()
    control = receipt_control(data, receipt.read_text(), invocation_relative, root=root)
    paths = [invocation, root / 'plugins/sdd-review-loop/references/review-context-boundary.md']
    paths.extend(root / entry['path'] for entry in data['allowed_input_manifest'])
    for path in paths:
        relative = path.relative_to(root)
        require(path.is_file() and not any(
            (root / pathlib.Path(*relative.parts[:index])).is_symlink()
            for index in range(1, len(relative.parts) + 1)),
                'impl admitted path is missing or symlinked')
    bash = list(control['hash_commands'])
    if data['stage'] != 'quality':
        bash.append('rtk proxy test -d domain')
    policy = {'schema': 'impl-nontty-pretool/v1',
              'read_paths': [str(path.resolve()) for path in paths],
              'bash_commands': bash}
    if data['stage'] in JSON_REVIEW_STAGES:
        policy['output_tool'] = 'StructuredOutput'
    guard = root / 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs'
    policy_bytes = json.dumps(policy, sort_keys=True, separators=(',', ':')).encode('utf-8')
    policy_sha256 = hashlib.sha256(policy_bytes).hexdigest()
    command = ('rtk proxy node ' + shlex.quote(str(guard)) + ' ' +
               shlex.quote(str(policy_path)) + ' ' + policy_sha256 + ' || exit 2')
    settings = {'permissions': {'allow': control['exact_permission_rules']},
                'hooks': {'PreToolUse': [
        {'matcher': '*', 'hooks': [{'type': 'command', 'command': command}]}]}}
    return policy_bytes, settings


def expected_prompt(root, invocation, receipt, *, strict=False, conditional_state=None):
    data, _ = manifest(root, invocation)
    enforced = data['stage'] in ('impl', 'task', 'quality') or strict
    receipt_text = receipt.read_bytes().decode('utf-8')
    require(re.fullmatch(r'REVIEW_CONTEXT_OK [0-9a-f]{64} sequence=[1-9][0-9]* '
                         r'previous_record_sha256=(?:-|[0-9a-f]{64}) pre_append_tip_sequence=(?:-|[0-9]+) '
                         r'identity_unique=yes\n?',
                         receipt_text) is not None, 'invalid reservation receipt text')
    relative = invocation.resolve().relative_to(root.resolve()).as_posix()
    binding = json.dumps({'role': data['role'], 'invocation': relative,
                          'invocation_sha256': sha(invocation),
                          'receipt': receipt_text.rstrip('\n')},
                         ensure_ascii=True, sort_keys=True)
    review_name = {'spec': 'spec', 'impl': 'implementation-policy', 'task': 'task-decomposition',
                   'quality': 'quality-gate'}[data['stage']]
    task_hash_note = (
        'Task transport raw SHA-256 observations: ' + json.dumps(admitted_raw_hashes(root, data), sort_keys=True)
        + '\nCompare file hash commands with these raw observations. The tasks.md manifest digest '
        'may instead be normalized by the canonical task precheck; never replace that manifest '
        'digest in the receipt or review output. Canonical verification remains mandatory.\n'
        if data['stage'] == 'task' else '')
    conditional_note = (
        'Pre-reservation conditional-input resolution, rechecked immediately before reservation '
        '(launch-control observation, not a review verdict): '
        + json.dumps(conditional_state, ensure_ascii=True, sort_keys=True) + '\n'
        + 'Use the observed presence and domain/design-system eligibility for the role checks and '
        'state the applicable SKIP reason. Do not run directory/presence shell probes; this session '
        'permits only the exact listed Bash commands. Inspect admitted substantive inputs independently.\n'
        if strict and data['stage'] in ('spec', 'impl') and conditional_state is not None else '')
    return ('SDD independent ' + review_name + ' review; manifest-only, read-only.\n'
            + binding + '\n'
            + ('Read tool file_path values (canonical absolute paths):\n'
               + json.dumps(canonical_read_paths(root, [relative, BOUNDARY_PATH] +
                            [entry['path'] for entry in data['allowed_input_manifest']]),
                            ensure_ascii=True) + '\n'
               'Use these exact absolute paths for Read; do not infer a different repository root. '
               'Keep relative paths unchanged in manifest, hash commands, receipt and output identities.\n'
               if enforced else '')
            + task_hash_note
            + conditional_note
            + control_prompt(data, receipt_text, sha(root / 'plugins/sdd-review-loop/references/review-context-boundary.md'),
                             strict=strict, invocation_path=relative,
                             invocation_sha256=sha(invocation), root=root if enforced else None)
            + 'Verify the invocation, reserved receipt and every admitted input hash using the '
            'canonical review-context contract before reading review inputs. Do not reserve again.\n'
            'Read only admitted inputs; follow the pinned role and precheck obligations. '
            'Do not read peer outputs or modify files. Stop on admission failure without a verdict.\n'
            + ('Use admitted Read for review analysis; do not run grep, jq, wc, diff, '
               'or any other unlisted Bash command in this exact-command non-TTY session.\n'
               if enforced else '')
            + ('Evaluate independently. Before deciding, read the admitted task, requirements, '
               'design, acceptance tests, contracts and applicable layer specifications yourself, '
               'then inspect the changed implementation and evidence for every in-scope criterion. '
               'Hash verification proves identity, not review coverage; an implementation report '
               'or earlier verdict cannot substitute for these reads. If required review coverage '
               'is incomplete, return NEEDS_WORK and name the unread inputs or unchecked criteria. '
               'Return the evaluator plaintext contract exactly: '
               'RUN_ID and HOST_SESSION_ID matching this invocation, ALLOWED_INPUT_MANIFEST '
               'as this invocation path followed by its SHA-256, VERDICT: PASS or NEEDS_WORK, '
               'then FINDINGS: and CHECKED: sections. This session allows only manifest Read '
               'and exact hash Bash: do not claim to rerun tests. Explicitly list task-required '
               'tests not rerun. Report only checks actually executed or inspected; if an in-scope '
               'behavior lacks evidence, return NEEDS_WORK, never PASS on the receipt alone. '
               'Do not write outside the declared scratch root.\n'
               if data['stage'] == 'quality' else
               'Evaluate independently. Return only the complete canonical role JSON with the '
               'invocation run/session identities; no markdown or omitted checks.\n')).encode('utf-8')


def native_delivery(root, invocation, transcript, prompt, wrapper, receipt, *, strict=False,
                    conditional_state=None):
    data, ledger = manifest(root, invocation)
    enforced = data['stage'] in ('impl', 'task', 'quality') or strict
    require(prompt.read_bytes() == expected_prompt(root, invocation, receipt, strict=strict,
                                                   conditional_state=conditional_state),
            'prompt differs from complete canonical launch template')
    session = data['host_session_id']
    require(sum(record.get('run_id') == session and record.get('host_session_id') == session
                for record in ledger['records']) == 1,
            'reserved identity absent or repeated')
    meta_turn_seen = False
    if enforced:
        control = receipt_control(data, receipt.read_text(), invocation.relative_to(root).as_posix(), root=root)
        record = next(record for record in ledger['records']
                      if record.get('run_id') == session and
                      record.get('host_session_id') == session)
        record_fields = [
            ('sequence', data['sequence']), ('stage', data['stage']),
            ('role', data['role']),
            ('previous_record_sha256', data['previous_record_sha256']),
            ('record_sha256', control['record_sha256'])]
        if data['stage'] == 'quality':
            record_fields.append(('scratch_declaration_sha256', control['scratch_declaration_sha256']))
        elif data['stage'] in ('spec', 'impl'):
            record_fields.append(('allowed_inputs_sha256', control['inputs_sha256']))
        require(all(record.get(field) == value for field, value in record_fields),
            'reserved ledger record differs from invocation or receipt')
    require(transcript.is_file() and transcript.name == session + '.jsonl',
            'native transcript missing or wrong session')
    result = load(wrapper)
    require(result.get('session_id') == session and result.get('is_error') is False and
            result.get('type') == 'result', 'host result did not accept proposed session')
    messages = [json.loads(line) for line in transcript.read_text().splitlines() if line.strip()]
    require(all(item.get('sessionId') == session or
                (item.get('type') == 'file-history-snapshot' and 'sessionId' not in item)
                for item in messages),
            'native transcript contains a different session')
    if enforced:
        allowed_reads = {invocation.resolve(),
                         (root / 'plugins/sdd-review-loop/references/review-context-boundary.md').resolve()}
        allowed_reads.update((root / entry['path']).resolve()
                             for entry in data['allowed_input_manifest'])
        allowed_bash = set(control['hash_commands'])
        batch_command = control['compact_command']
        if data['stage'] != 'quality':
            allowed_bash.add('rtk proxy test -d domain')
        required_hashes: dict[str, str | None] = {batch_command: None}
        required_order = list(required_hashes)
        file_hash_order = [batch_command]
        proven: set[str] = set()
        pending: dict[str, Any] = {}
        used_tool_ids = set()
        issued_file_hashes = 0
        retries = set()
        first_bash = None
        must_retry = None
        output_tool = object()
        structured_seen = False
        structured_complete = False
        first_prompt_seen = False
        for item in messages:
            content = item.get('message', {}).get('content', [])
            if strict and data['stage'] in JSON_REVIEW_STAGES and item.get('type') == 'user' \
                    and isinstance(content, str):
                if not first_prompt_seen:
                    require(item.get('isMeta') is not True and
                            content.encode('utf-8') == prompt.read_bytes(),
                            'native first-turn prompt is absent or preceded')
                    first_prompt_seen = True
                else:
                    require(item.get('isMeta') is True and
                            content == STRUCTURED_OUTPUT_ENFORCE_TURN and
                            not meta_turn_seen and not structured_seen and not pending and
                            set(required_hashes) <= proven,
                            'unexpected JSON review user or structured-output meta turn')
                    meta_turn_seen = True
            for block in content if isinstance(content, list) else []:
                if not isinstance(block, dict):
                    continue
                if block.get('type') == 'tool_result':
                    tool_id = block.get('tool_use_id')
                    if not isinstance(tool_id, str) or tool_id not in pending:
                        raise ValueError('impl tool result lacks matching use')
                    command = pending.pop(tool_id)
                    result_text = block.get('content')
                    if command is output_tool:
                        require(block.get('is_error') is not True,
                                'JSON review StructuredOutput result failed')
                        structured_complete = True
                    elif command in required_hashes:
                        if block.get('is_error') is True:
                            require(command == first_bash and command not in retries and
                                    isinstance(result_text, str) and
                                    'Fact-Forcing Gate' in result_text,
                                    'impl hash refusal is not the one allowed first-Bash retry')
                            retries.add(command)
                            must_retry = command
                        else:
                            require(block.get('is_error') is False and
                                    command not in proven,
                                    'impl hash tool result differs from pinned digest')
                            if command == batch_command:
                                require_compact_result(result_text, control['compact_output'])
                            else:
                                expected_hash = required_hashes[command]
                                require(isinstance(expected_hash, str) and
                                        isinstance(result_text, str) and
                                        result_text.rstrip('\n') == expected_hash +
                                        '  -' and result_text.count('\n') <= 1,
                                        'impl control hash tool result differs from pinned digest')
                            if command not in file_hash_order:
                                require(command == required_order[len(proven)],
                                        'impl hash success is out of required order')
                            proven.add(command)
                            if must_retry == command:
                                must_retry = None
                    elif command is None:
                        require(block.get('is_error') is not True,
                                'impl admitted Read failed')
                    continue
                if block.get('type') != 'tool_use':
                    require('tool_use' not in str(block.get('type')), 'unrecognized impl tool-use type')
                    continue
                require(item.get('type') == 'assistant', 'impl tool use outside assistant turn')
                name, tool_input = block.get('name'), block.get('input')
                if not isinstance(tool_input, dict):
                    raise ValueError('impl tool input is malformed')
                require(not structured_seen, 'tool call after JSON review StructuredOutput')
                if must_retry is not None:
                    require(name == 'Bash' and tool_input.get('command') == must_retry,
                            'impl first-Bash retry was not immediate and identical')
                if name == 'Read':
                    require(all(command is None for command in pending.values()),
                            'impl Read overlapped pending hash proof')
                    value = tool_input.get('file_path')
                    if not isinstance(value, str) or not value:
                        raise ValueError('impl Read path missing')
                    target = pathlib.Path(value)
                    target = (target if target.is_absolute() else root / target).resolve()
                    require(target in allowed_reads, 'impl Read outside admitted inputs')
                    if target not in {invocation.resolve(),
                                      (root / 'plugins/sdd-review-loop/references/review-context-boundary.md').resolve()}:
                        require(set(required_hashes) <= proven,
                                'impl substantive Read preceded required hash proof')
                    require(isinstance(block.get('id'), str) and block['id'] not in used_tool_ids,
                            'impl Read tool-use identity invalid')
                    used_tool_ids.add(block['id'])
                    pending[block['id']] = None
                elif name == 'Bash':
                    command = tool_input.get('command')
                    require(command in allowed_bash,
                            'impl Bash outside exact launch commands')
                    require(command not in proven, 'impl Bash repeats a proven hash')
                    if command in required_hashes:
                        require(command not in pending.values(),
                                'impl duplicate pending hash command')
                        if command in file_hash_order:
                            if must_retry is not None:
                                require(command == file_hash_order[0] and not pending,
                                        'impl first Bash retry overlapped another tool')
                            else:
                                require(issued_file_hashes < len(file_hash_order) and
                                        command == file_hash_order[issued_file_hashes],
                                        'impl file hash issue is out of required order')
                                if issued_file_hashes:
                                    require(file_hash_order[0] in proven,
                                            'impl first Bash hash has not succeeded')
                                    require(all(value in file_hash_order for value in pending.values()),
                                            'impl file hashes overlapped a non-file tool')
                                else:
                                    require(not pending, 'impl first Bash hash overlapped another tool')
                                issued_file_hashes += 1
                        else:
                            require(not pending and set(file_hash_order) <= proven,
                                    'impl control hash commands were not serialized')
                            require(command == required_order[len(proven)],
                                    'impl control hash issue is out of required order')
                    else:
                        require(not pending, 'impl non-hash Bash overlapped pending hash proof')
                    require(isinstance(block.get('id'), str) and block['id'] not in used_tool_ids,
                            'impl Bash tool-use identity invalid')
                    used_tool_ids.add(block['id'])
                    if first_bash is None:
                        first_bash = command
                    pending[block['id']] = command
                elif name == 'StructuredOutput' and data['stage'] in JSON_REVIEW_STAGES and strict:
                    require(not pending and set(required_hashes) <= proven,
                            'JSON review StructuredOutput preceded hash proof or tool result')
                    require(isinstance(block.get('id'), str) and block['id'] not in used_tool_ids,
                            'JSON review StructuredOutput identity invalid')
                    used_tool_ids.add(block['id'])
                    pending[block['id']] = output_tool
                    structured_seen = True
                else:
                    raise ValueError('impl used a tool outside Read/Bash')
        require(not pending and set(required_hashes) <= proven,
                'impl native transcript lacks complete hash proof')
        if data['stage'] in JSON_REVIEW_STAGES and strict:
            require(structured_seen and structured_complete,
                    'JSON review StructuredOutput call and result missing')
    user_turns = [item for item in messages if item.get('type') == 'user']
    user_content = [item.get('message', {}).get('content')
                    for item in user_turns if isinstance(item.get('message'), dict)]
    first_turns = [content for content in user_content if isinstance(content, str)]
    tool_returns = [content for content in user_content if isinstance(content, list) and
                    content and all(isinstance(block, dict) and block.get('type') == 'tool_result'
                                    for block in content)]
    expected_string_turns = (1 + int(meta_turn_seen) if enforced and strict and
                             data['stage'] in JSON_REVIEW_STAGES else 1)
    require(len(first_turns) == expected_string_turns and
            user_content[0] == first_turns[0] and
            first_turns[0].encode('utf-8') == prompt.read_bytes() and
            len(user_turns) == len(user_content) == len(first_turns) + len(tool_returns),
            'native first-turn prompt is absent, truncated, or preceded by another user turn')
    return data, result, messages


def postflight(root, invocation, transcript, prompt, wrapper, receipt, *, strict=False,
               conditional_state=None):
    data, result, messages = native_delivery(root, invocation, transcript, prompt, wrapper,
                                             receipt, strict=strict,
                                             conditional_state=conditional_state)
    session = data['host_session_id']
    raw = result.get('result')
    require(isinstance(raw, str), 'reviewer result is not text')
    if data['stage'] == 'quality':
        lines = raw.splitlines()
        invocation_ref = invocation.resolve().relative_to(root.resolve()).as_posix()
        manifest_line = 'ALLOWED_INPUT_MANIFEST: ' + invocation_ref + ' ' + sha(invocation)
        verdicts = re.findall(r'^VERDICT: (PASS|NEEDS_WORK)$', raw, re.MULTILINE)
        checked = lines[lines.index('CHECKED:') + 1:] if 'CHECKED:' in lines else []
        require(sum(line.startswith('RUN_ID:') for line in lines) == 1 and
                sum(line.startswith('HOST_SESSION_ID:') for line in lines) == 1 and
                sum(line.startswith('ALLOWED_INPUT_MANIFEST:') for line in lines) == 1 and
                'RUN_ID: ' + session in lines and
                'HOST_SESSION_ID: ' + session in lines and
                manifest_line in lines and
                len(verdicts) == 1 and lines.count('FINDINGS:') == 1 and
                lines.count('CHECKED:') == 1 and
                any(line.startswith('- ') for line in checked),
                'evaluator plaintext verdict contract missing')
        if verdicts[0] == 'PASS':
            require(not any(re.match(r'- \[(?:Critical|Major)\]', line)
                            for line in lines), 'evaluator PASS has blocking findings')
            admitted = {(root / entry['path']).resolve()
                        for entry in data['allowed_input_manifest']}
            observed_reads = [block.get('input', {}).get('file_path')
                              for item in messages
                              for block in item.get('message', {}).get('content', [])
                              if isinstance(block, dict) and block.get('type') == 'tool_use'
                              and block.get('name') == 'Read'
                              and isinstance(block.get('input'), dict)]
            require(any(pathlib.Path(path).resolve() in admitted if pathlib.Path(path).is_absolute()
                        else (root / path).resolve() in admitted
                        for path in observed_reads if isinstance(path, str) and path),
                    'evaluator PASS lacks observed admitted input inspection')
        return {'status': 'DELIVERY_OK', 'session_id': session,
                'prompt_sha256': sha(prompt), 'prompt_bytes': len(prompt.read_bytes()),
                'transcript_sha256': sha(transcript), 'wrapper_sha256': sha(wrapper)}
    output = json.loads(raw)
    if data['stage'] in JSON_REVIEW_STAGES and strict:
        require(isinstance(output, dict) and result.get('structured_output') == output,
                'JSON review structured output differs from raw reviewer JSON')
    expected_stage = 'task-review' if data['role'] == 'task-reviewer-a' else data['stage']
    expected_role = 'reviewer-a' if data['role'] == 'task-reviewer-a' else data['role']
    require(output.get('stage') == expected_stage and output.get('role') == expected_role and
            output.get('run_id') == session and output.get('host_session_id') == session,
            'reviewer output identity mismatch')
    return {'status': 'DELIVERY_OK', 'session_id': session,
            'prompt_sha256': sha(prompt), 'prompt_bytes': len(prompt.read_bytes()),
            'transcript_sha256': sha(transcript), 'wrapper_sha256': sha(wrapper)}


def verify_session_collision(result, session, before, after):
    require(result.returncode == 1 and not result.stdout.strip() and
            result.stderr.strip() == f'Error: Session ID {session} is already in use.' and
            before == after, 'existing session was not rejected without transcript mutation')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('phase', choices=('preflight', 'postflight'))
    parser.add_argument('root', type=pathlib.Path)
    parser.add_argument('invocation', type=pathlib.Path)
    parser.add_argument('transcript', type=pathlib.Path)
    parser.add_argument('--prompt', type=pathlib.Path)
    parser.add_argument('--wrapper', type=pathlib.Path)
    parser.add_argument('--receipt', type=pathlib.Path)
    args = parser.parse_args()
    root = args.root.resolve()
    require(args.invocation.is_file(), 'invocation missing')
    if args.phase == 'preflight':
        require(args.prompt is None and args.wrapper is None and args.receipt is None,
                'preflight takes no output files')
        print(json.dumps(preflight(root, args.invocation, args.transcript), sort_keys=True))
    else:
        require(args.prompt is not None and args.wrapper is not None and
                args.prompt.is_file() and args.wrapper.is_file() and
                args.receipt is not None and args.receipt.is_file(), 'postflight files missing')
        print(json.dumps(postflight(root, args.invocation, args.transcript,
                                    args.prompt, args.wrapper, args.receipt), sort_keys=True))


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError, json.JSONDecodeError) as error:
        print('NONTTY_LAUNCH_REJECTED: ' + str(error), file=sys.stderr)
        sys.exit(1)
