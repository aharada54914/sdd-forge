#!/usr/bin/env python3
"""Synthetic negative fixture for the candidate launch proof, not a live review."""
import hashlib
import json
import pathlib
import runpy
import tempfile
import uuid


SOURCE = pathlib.Path(__file__).with_name('validate-nontty-spec-launch.py.candidate')
code = runpy.run_path(str(SOURCE))
preflight = code['preflight']
def postflight(root, inv, trace, prompt, wrap):
    return code['postflight'](root, inv, trace, prompt, wrap, root / 'receipt.txt')


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value) + '\n' if not isinstance(value, str) else value)


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def setup(root):
    session = str(uuid.uuid4())
    ledger = root / 'reports/review-context/identity-ledger.json'
    write(ledger, {'schema': 'review-identity-ledger/v1', 'records': []})
    invocation = root / 'invocation.json'
    data = {'schema': 'review-context-invocation/v2', 'stage': 'spec',
            'role': 'spec-reviewer-a', 'feature': 'fixture',
            'read_only': True, 'input_mode': 'file-manifest', 'fallback_mode': 'none',
            'run_id': session, 'host_session_id': session,
            'identity_ledger_path': 'reports/review-context/identity-ledger.json',
            'identity_ledger_sha256': digest(ledger)}
    write(invocation, data)
    transcript = root / (session + '.jsonl')
    prompt = root / 'prompt.txt'
    write(root / 'receipt.txt', 'REVIEW_CONTEXT_OK ' + 'a' * 64 +
          ' sequence=1 previous_record_sha256=' + 'b' * 64 +
          ' pre_append_tip_sequence=- identity_unique=yes\n')
    write(prompt, code['expected_prompt'](root, invocation, root / 'receipt.txt').decode('utf-8'))
    wrapper = root / 'wrapper.json'
    output = {'stage': 'spec', 'role': 'spec-reviewer-a',
              'run_id': session, 'host_session_id': session}
    write(wrapper, {'type': 'result', 'session_id': session, 'is_error': False,
                    'result': json.dumps(output)})
    transcript_row = {'type': 'user', 'sessionId': session,
                      'message': {'content': prompt.read_text()}}
    return session, ledger, invocation, transcript, prompt, wrapper, transcript_row


def reject(label, call):
    try:
        call()
    except (ValueError, KeyError, TypeError):
        print('PASS ' + label)
        return
    raise AssertionError('ACCEPTED ' + label)


def main():
    with tempfile.TemporaryDirectory(prefix='a7-nontty-fixture-') as temp:
        root = pathlib.Path(temp)
        session, ledger, inv, trace, prompt, wrap, row = setup(root)
        assert preflight(root, inv, trace)['session_id'] == session
        print('PASS fresh-preflight')
        write(trace, json.dumps(row) + '\n')
        reject('existing-session', lambda: preflight(root, inv, trace))
        trace.unlink()
        write(ledger, {'schema': 'review-identity-ledger/v1',
                       'records': [{'run_id': session, 'host_session_id': 'another'}]})
        reject('ledger-reuse', lambda: preflight(root, inv, trace))
        write(ledger, {'schema': 'review-identity-ledger/v1', 'records': []})
        bad_inv = json.loads(inv.read_text())
        bad_inv['run_id'] = str(uuid.uuid4())
        write(inv, bad_inv)
        reject('separate-run-id', lambda: preflight(root, inv, trace))
        bad_inv['run_id'] = session
        bad_inv['host_session_id'] = 'not-a-uuid'
        write(inv, bad_inv)
        reject('invalid-uuid', lambda: preflight(root, inv, trace))
        bad_inv['host_session_id'] = session
        write(inv, bad_inv)
        write(trace, json.dumps(row) + '\n')
        reject('missing-reservation', lambda: postflight(root, inv, trace, prompt, wrap))
        write(ledger, {'schema': 'review-identity-ledger/v1',
                       'records': [{'run_id': session, 'host_session_id': session}]})
        write(trace, json.dumps(row) + '\n')
        assert postflight(root, inv, trace, prompt, wrap)['prompt_bytes'] == len(prompt.read_bytes())
        print('PASS full-delivery')
        receipt = root / 'receipt.txt'
        saved_receipt = receipt.read_text()
        write(receipt, saved_receipt.replace('sequence=1', 'sequence=2'))
        reject('changed-receipt', lambda: postflight(root, inv, trace, prompt, wrap))
        write(receipt, 'not a receipt\n')
        reject('malformed-receipt', lambda: postflight(root, inv, trace, prompt, wrap))
        write(receipt, saved_receipt)
        write(receipt, saved_receipt.replace(' identity_unique=yes', ''))
        reject('missing-identity-uniqueness', lambda: postflight(root, inv, trace, prompt, wrap))
        write(receipt, saved_receipt.replace('identity_unique=yes', 'identity_unique=no'))
        reject('false-identity-uniqueness', lambda: postflight(root, inv, trace, prompt, wrap))
        write(receipt, saved_receipt)
        saved_inv = inv.read_text()
        changed = json.loads(saved_inv)
        changed['feature'] = 'substituted'
        write(inv, changed)
        reject('changed-invocation', lambda: postflight(root, inv, trace, prompt, wrap))
        write(inv, saved_inv)
        tool_return = {'type': 'user', 'sessionId': session,
                       'message': {'content': [{'type': 'tool_result', 'content': 'fixture'}]}}
        snapshot = {'type': 'file-history-snapshot'}
        write(trace, json.dumps(snapshot) + '\n' + json.dumps(row) + '\n' +
              json.dumps(tool_return) + '\n')
        assert postflight(root, inv, trace, prompt, wrap)['prompt_bytes'] == len(prompt.read_bytes())
        print('PASS native-tool-return-and-file-history')
        complete = prompt.read_text()
        write(prompt, complete[-4:])
        row['message']['content'] = complete[-4:]
        write(trace, json.dumps(row) + '\n')
        reject('both-prompt-and-transcript-truncated',
               lambda: postflight(root, inv, trace, prompt, wrap))
        write(prompt, complete)
        row['message']['content'] = complete
        write(trace, json.dumps(row) + '\n')
        wrong = json.loads(wrap.read_text())
        wrong['session_id'] = str(uuid.uuid4())
        write(wrap, wrong)
        reject('host-id-mismatch', lambda: postflight(root, inv, trace, prompt, wrap))
        wrong['session_id'] = session
        wrong['is_error'] = True
        write(wrap, wrong)
        reject('host-error', lambda: postflight(root, inv, trace, prompt, wrap))
        wrong['is_error'] = False
        output = json.loads(wrong['result'])
        output['run_id'] = str(uuid.uuid4())
        wrong['result'] = json.dumps(output)
        write(wrap, wrong)
        reject('model-output-id-mismatch', lambda: postflight(root, inv, trace, prompt, wrap))
        output['run_id'] = session
        wrong['result'] = json.dumps(output)
        write(wrap, wrong)
        row['message']['content'] = prompt.read_text()[:-4]
        write(trace, json.dumps(row) + '\n')
        reject('truncated-prompt', lambda: postflight(root, inv, trace, prompt, wrap))
        row['message']['content'] = prompt.read_text()
        extra = {'type': 'user', 'sessionId': session,
                 'message': {'content': [{'type': 'text', 'text': 'new human turn'}]}}
        write(trace, json.dumps(row) + '\n' + json.dumps(extra) + '\n')
        reject('extra-user-array-turn', lambda: postflight(root, inv, trace, prompt, wrap))
        write(trace, json.dumps(row) + '\n' + json.dumps(row) + '\n')
        reject('reused-conversation', lambda: postflight(root, inv, trace, prompt, wrap))
        write(ledger, {'schema': 'review-identity-ledger/v1',
                       'records': [{'run_id': session, 'host_session_id': session}] * 2})
        reject('double-reservation', lambda: postflight(root, inv, trace, prompt, wrap))


if __name__ == '__main__':
    main()
