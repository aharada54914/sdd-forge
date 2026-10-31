"""Isolated proposal for the existing transport helper; not a live launcher."""
import hashlib
import json
import re
import shlex


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
