#!/usr/bin/env python3
"""Candidate-only, read-only proof for caller-proposed non-TTY Claude IDs.

This does not reserve an identity or approve a review verdict. The normal
review-context validator still owns reservation and output schema checks.
"""
import argparse
import hashlib
import json
import pathlib
import re
import shlex
import sys
import uuid


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
    require(data.get('schema') == 'review-context-invocation/v2' and
            data.get('stage') == 'spec' and
            data.get('role') in ('spec-reviewer-a', 'spec-reviewer-b') and
            data.get('read_only') is True and
            data.get('input_mode') == 'file-manifest' and
            data.get('fallback_mode') == 'none', 'not a read-only spec invocation')
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
    require(all(record.get('run_id') != session and record.get('host_session_id') != session
                for record in ledger['records']), 'proposed identity already appears in ledger')
    require(sha(root / data['identity_ledger_path']) == data.get('identity_ledger_sha256'),
            'invocation ledger pin is stale')
    return {'status': 'PREFLIGHT_OK', 'session_id': session,
            'invocation_sha256': sha(invocation)}


def receipt_control(data, receipt_text):
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
                entry['path'] in paths or not isinstance(entry['sha256'], str) or
                re.fullmatch('[0-9a-f]{64}', entry['sha256']) is None):
            raise ValueError('invalid ordered input entry')
        paths.add(entry['path'])
    inputs_text = '\n'.join(entry['path'] + '\t' + entry['sha256'] for entry in entries)
    inputs_hash = hashlib.sha256(inputs_text.encode('utf-8')).hexdigest()
    fields = [str(data['sequence']), data['stage'], data['role'], data['run_id'],
              data['host_session_id'], previous]
    if any(not isinstance(v, str) or any(c in v for c in '|\r\n\x00') for v in fields):
        raise ValueError('invalid record field')
    record_text = '|'.join(fields) + '|allowed-inputs-v1|' + inputs_hash
    if hashlib.sha256(record_text.encode('utf-8')).hexdigest() != digest:
        raise ValueError('receipt record hash mismatch')
    commands = ["printf '%s' " + shlex.quote(text) + ' | rtk proxy shasum -a 256'
                for text in (inputs_text, record_text)]
    return {'inputs_text': inputs_text, 'inputs_sha256': inputs_hash,
            'record_text': record_text, 'record_sha256': digest,
            'hash_commands': commands}


def control_prompt(data, receipt_text, boundary_sha256):
    control = receipt_control(data, receipt_text)
    control['boundary_path'] = 'plugins/sdd-review-loop/references/review-context-boundary.md'
    control['boundary_sha256'] = boundary_sha256
    return (
        'Launch-control input (not peer evidence): read and hash the boundary document below.\n'
        + json.dumps(control, ensure_ascii=True, sort_keys=True) + '\n'
        'Independently reconstruct inputs_text from the ordered invocation entries as path TAB sha256 '
        'joined with LF, no terminal newline. Hash its exact UTF-8 bytes. Reconstruct record_text as '
        'sequence|stage|role|run_id|host_session_id|previous_record_sha256 followed by '
        '|allowed-inputs-v1| and that input digest. Hash its exact UTF-8 bytes. '
        'Use the two literal no-newline hash commands only after checking their text against this '
        'independent reconstruction. Caller-provided digests alone are not reviewer proof. '
        'Require equality to the quoted receipt and sequence=tip+1, previous link equality and '
        'identity_unique=yes before reviewing substantive inputs. If any operation cannot be '
        'performed, stop without a verdict. Never inspect the ledger or reserve again.\n')


def expected_prompt(root, invocation, receipt):
    data, _ = manifest(root, invocation)
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
    return ('SDD independent spec review; manifest-only, read-only.\n'
            + binding + '\n'
            + control_prompt(data, receipt_text, sha(root / 'plugins/sdd-review-loop/references/review-context-boundary.md'))
            + 'Verify the invocation, reserved receipt and every admitted input hash using the '
            'canonical review-context contract before reading review inputs. Do not reserve again.\n'
            'Read only admitted inputs; follow the pinned role and precheck obligations. '
            'Do not read peer outputs or modify files. Stop on admission failure without a verdict.\n'
            'Evaluate independently. Return only the complete canonical role JSON with the '
            'invocation run/session identities; no markdown or omitted checks.\n').encode('utf-8')


def native_delivery(root, invocation, transcript, prompt, wrapper, receipt):
    data, ledger = manifest(root, invocation)
    require(prompt.read_bytes() == expected_prompt(root, invocation, receipt),
            'prompt differs from complete canonical launch template')
    session = data['host_session_id']
    require(sum(record.get('run_id') == session and record.get('host_session_id') == session
                for record in ledger['records']) == 1,
            'reserved identity absent or repeated')
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
    user_turns = [item for item in messages if item.get('type') == 'user']
    user_content = [item.get('message', {}).get('content')
                    for item in user_turns if isinstance(item.get('message'), dict)]
    first_turns = [content for content in user_content if isinstance(content, str)]
    tool_returns = [content for content in user_content if isinstance(content, list) and
                    content and all(isinstance(block, dict) and block.get('type') == 'tool_result'
                                    for block in content)]
    require(len(first_turns) == 1 and user_content[0] == first_turns[0] and
            first_turns[0].encode('utf-8') == prompt.read_bytes() and
            len(user_turns) == len(user_content) == len(first_turns) + len(tool_returns),
            'native first-turn prompt is absent, truncated, or preceded by another user turn')
    return data, result, messages


def postflight(root, invocation, transcript, prompt, wrapper, receipt):
    data, result, _ = native_delivery(root, invocation, transcript, prompt, wrapper, receipt)
    session = data['host_session_id']
    raw = result.get('result')
    require(isinstance(raw, str), 'reviewer result is not text')
    output = json.loads(raw)
    require(output.get('stage') == 'spec' and output.get('role') == data['role'] and
            output.get('run_id') == session and output.get('host_session_id') == session,
            'reviewer output identity mismatch')
    return {'status': 'DELIVERY_OK', 'session_id': session,
            'prompt_sha256': sha(prompt), 'prompt_bytes': len(prompt.read_bytes()),
            'transcript_sha256': sha(transcript), 'wrapper_sha256': sha(wrapper)}


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
