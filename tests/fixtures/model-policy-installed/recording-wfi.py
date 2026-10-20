#!/usr/bin/env python3
"""External ordinary Claude fixture for the original WFI auditors: public JSON result, admitted Reads, no backend.

FIXTURE ONLY. It validates the exact native argv, the generated read-only settings and the delivered bytes, performs
every Read through the generated hook command (the original Node guard) BEFORE reading, and returns configured
original-schema audit JSON as the public `result` string. It shows no model intelligence, audit correctness, human
approval, OS isolation, actual backend identity or provider availability.
"""
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import uuid
from typing import Any

A_IDS = ['EVIDENCE-CITED', 'ROOT-CAUSE-PLAUSIBLE', 'WHY-CHAIN-VALID', 'CATEGORY-LANGUAGE-MATCH', 'CHANGE-CONCRETE',
         'EFFECT-MEASURABLE', 'VERIFICATION-METRIC-DEFINED', 'VERIFICATION-PLAN-SPECIFIC', 'NO-PLUGIN-SCOPE-CREEP']
B_IDS = ['VERIFICATION-COMPLETE', 'SCOPE-PROPORTIONAL', 'UNINTENDED-CONSEQUENCES', 'FEASIBILITY-WITHOUT-PLUGINS',
         'CATEGORY-LANGUAGE-SECOND-PASS', 'EFFECT-CONSISTENT-WITH-EVIDENCE', 'ISSUE-BODY-QUALITY',
         'META-CHANGE-ANTI-GOODHART']
DENIAL = {'hookSpecificOutput': {'hookEventName': 'PreToolUse', 'permissionDecision': 'deny',
                                 'permissionDecisionReason': 'Impl non-TTY tool call differs from caller-pinned inputs'}}
PAIRS = {'--output-format', '--model', '--effort', '--session-id', '--agent', '--agents', '--tools',
         '--disallowedTools', '--settings'}
AGENT_KEYS = {'description', 'prompt', 'tools', 'disallowedTools', 'model', 'effort'}
DISALLOWED = ['Grep', 'Glob', 'Write', 'Edit', 'NotebookEdit']
LIMIT = 16 * 1024 * 1024


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


def audit(spec, reads):
    """Original wfi-auditor-a/b v1 shape; B's cycle_1_summary is copied from the bridge it actually Read."""
    kind, mode = spec['kind'], spec.get('reply_mode', 'success')
    ids = A_IDS if kind == 'a' else B_IDS
    checks = [{'id': name, 'result': 'PASS', 'severity': 'Major', 'finding': 'No issues found.'} for name in ids]
    document = {'schema': 'wfi-auditor-%s/v1' % kind, 'wfi_id': spec['wfi_id'], 'category': 'plugin-improvement',
                'cycle': 1 if kind == 'a' else 2, 'verdict': 'PASS'}
    if kind == 'a':
        if not spec['has_retrospective']:  # the existing no-report instruction, not a fabricated report
            checks[0].update(result='SKIP', finding='No retrospective report provided; cannot verify evidence citations.')
        advisory = checks[7]  # an advisory Minor FAIL does not change a PASS verdict
        advisory.update(result='FAIL', severity='Minor', finding='Fixture advisory ' + spec['a_canary'])
        revisions = [{'section': '## Verification Plan', 'change': 'Fixture revision ' + spec['a_canary'],
                      'rationale': 'Fixture advisory only.'}]
    else:
        summary = json.loads(reads[spec['summary_sha256']])
        document['cycle_1_summary'] = {key: summary[key] for key in
                                       ('auditor_a_fail_count', 'auditor_a_pass_count', 'auditor_a_verdict')}
        checks[0]['finding'] = 'Fixture observed ' + spec['marker']
        checks[7].update(result='SKIP', severity='Critical', finding='Meta-Change is not set; the strict lane does not apply.')
        revisions = []
    document.update(checks=checks, proposed_revisions=revisions)
    if mode == 'wrong-schema':
        document['schema'] = 'wfi-auditor-%s/v1' % ('b' if kind == 'a' else 'a')
    elif mode == 'wrong-wfi':
        document['wfi_id'] = 'WFI-002'
    elif mode == 'wrong-cycle':
        document['cycle'] = 2 if kind == 'a' else 1
    return json.dumps(document, sort_keys=True)


def main():
    spec = json.loads(Path(os.environ['SDD_WFI_FIXTURE']).read_text())
    argv = sys.argv[1:]
    event = {'argv': argv}
    log = Path(spec['log'])

    def note(kind, **data):
        with log.open('a') as output:
            output.write(json.dumps({'event': kind, **event, **data}, sort_keys=True) + '\n')

    if argv in (['--help'], ['--version']):
        with Path(spec['calls']).open('a') as calls:
            calls.write(argv[0] + '\n')
    if argv == ['--help']:
        note('help')
        for edit in spec.get('edit_on_help', []):
            Path(edit['path']).write_text(edit['text'])
        print(spec['help'], end='')
        return 0
    if argv == ['--version']:
        note('version')
        print(spec['version'])
        return 0
    payload = sys.stdin.read(LIMIT + 1)
    tools = []
    try:
        assert len(payload.encode()) <= LIMIT
        options: dict[str, Any] = {}
        index = 0
        while index < len(argv):  # closed option grammar: no resume, bypass, history or unrelated grants
            key = argv[index]
            assert key not in options, 'duplicate native option'
            if key in ('--print', '--verbose'):
                options[key] = True
                index += 1
            else:
                assert key in PAIRS and index + 1 < len(argv), 'unexpected native option ' + key
                options[key] = argv[index + 1]
                index += 2
        assert options['--print'] is True and options['--output-format'] == 'json'
        assert options['--model'] == spec['model'] and options['--effort'] == spec['effort']
        session = options['--session-id']
        parsed = uuid.UUID(session)
        assert parsed.int and str(parsed) == session == spec['session_id'], 'not the fresh canonical UUID'
        sessions = Path(spec['sessions'])
        previous = sessions.read_text().splitlines() if sessions.exists() else []
        assert session not in previous, 'native session already exists; resume is forbidden'
        assert options['--agent'] == spec['agent']
        assert options['--tools'].split(',') == ['Read', 'Bash']
        assert sorted(options['--disallowedTools'].split(',')) == sorted(DISALLOWED)
        agents = json.loads(options['--agents'])
        assert set(agents) == {spec['agent']}
        agent = agents[spec['agent']]
        assert {'description', 'prompt', 'model', 'effort'} <= set(agent) <= AGENT_KEYS, 'unsupported agent keys'
        assert isinstance(agent['description'], str) and agent['description']
        assert agent['prompt'].strip() == spec['role_body'].strip(), 'agent.prompt is not the complete original role body'
        assert (agent['model'], agent['effort']) == (spec['model'], spec['effort'])
        assert agent.get('tools', ['Read', 'Bash']) == ['Read', 'Bash']
        assert sorted(agent.get('disallowedTools', DISALLOWED)) == sorted(DISALLOWED)
        assert os.path.realpath(os.getcwd()) == spec['project'], 'unexpected working directory'
        assert os.environ.get(spec['canary_name']) == spec['canary_value']
        output = Path(spec['output_dir'])
        assert Path(options['--settings']) == output / 'readonly-settings.json', 'unexpected --settings path'

        def canaries_intact():
            for path, digest in spec['canaries'].items():
                assert sha(Path(path).read_bytes()) == digest, 'native settings or state changed: ' + path

        canaries_intact()
        settings = json.loads((output / 'readonly-settings.json').read_bytes())
        assert set(settings) == {'permissions', 'hooks'} and settings['permissions'] == {'allow': ['Read']}
        assert set(settings['hooks']) == {'PreToolUse'} and len(settings['hooks']['PreToolUse']) == 1
        group = settings['hooks']['PreToolUse'][0]
        assert set(group) == {'matcher', 'hooks'} and group['matcher'] == '*' and len(group['hooks']) == 1
        assert set(group['hooks'][0]) == {'type', 'command'} and group['hooks'][0]['type'] == 'command'
        command = group['hooks'][0]['command']
        assert 'rtk' not in command, 'the hook must not depend on RTK telemetry'
        parts = shlex.split(command)
        assert len(parts) == 7 and parts[4:] == ['||', 'exit', '2'], 'unexpected hook command shape'
        assert parts[0] == spec['node'] and sha(Path(parts[0]).read_bytes()) == spec['node_sha256'], 'unpinned Node'
        assert parts[1] == spec['guard'] and sha(Path(parts[1]).read_bytes()) == spec['guard_sha256'], 'unpinned guard'
        assert parts[2] == str(output / 'readonly-policy.json') and len(parts[3]) == 64
        policy_raw = Path(parts[2]).read_bytes()
        assert sha(policy_raw) == parts[3], 'the hook must pin the exact policy bytes'
        policy = json.loads(policy_raw)
        assert policy['schema'] == 'impl-nontty-pretool/v1' and policy['bash_commands'] == []
        assert set(policy) <= {'schema', 'read_paths', 'bash_commands', 'output_tool'}
        base = os.path.realpath(output / 'readonly-inputs')
        for path in policy['read_paths']:
            assert path == os.path.realpath(path) and path.startswith(base + os.sep) and os.path.isfile(path), path
        # Delivery: complete role only as agent.prompt, complete guide and current WFI once, no draft/raw audit bytes.
        assert payload.count(spec['guide']) == 1, 'the complete category guide must be delivered exactly once'
        assert payload.count(spec['wfi_text']) == 1, 'the current WFI must be delivered exactly once'
        assert spec['role_body'].strip() not in payload, 'the role body belongs only in agent.prompt'
        haystack = payload + '\n'.join(argv) + json.dumps(agents)

        def hook(tool, tool_input):
            event_json = json.dumps({'session_id': session, 'transcript_path': str(output / 'transcript.jsonl'),
                                     'cwd': spec['project'], 'hook_event_name': 'PreToolUse', 'tool_name': tool,
                                     'tool_input': tool_input})
            return subprocess.run(['/bin/sh', '-c', command], input=event_json, text=True, capture_output=True,
                                  cwd=spec['project'], env=os.environ.copy(), timeout=60, check=False)

        reads = {}
        for path in policy['read_paths']:  # the permitted Read is decided by the original guard BEFORE the bytes are read
            decision = hook('Read', {'file_path': path})
            assert (decision.returncode, decision.stdout, decision.stderr) == (0, '', ''), 'admitted Read was denied'
            raw = Path(path).read_bytes()
            reads[sha(raw)] = raw
            tools.append({'tool': 'Read', 'decision': 'allow', 'path': path, 'sha256': sha(raw)})
        assert sorted(reads) == sorted(spec['expected_sha256']), 'the Read set is not exactly the frozen inputs'
        assert len(policy['read_paths']) == len(spec['expected_sha256'])
        denied = [('Read', {'file_path': path}) for path in spec['forbidden'] if os.path.exists(path)]
        denied.append(('Bash', {'command': 'sha256sum ' + policy['read_paths'][0]}))  # even a benign hash is denied
        for tool, tool_input in denied:
            decision = hook(tool, tool_input)
            assert decision.returncode == 0 and json.loads(decision.stdout) == DENIAL, 'a forbidden event was admitted'
            tools.append({'tool': tool, 'decision': 'deny', 'input': tool_input})
        text = reads[sha(spec['wfi_text'].encode())].decode()
        assert spec['marker'] in text, 'the frozen WFI is not the current content'
        for forbidden in spec['absent']:
            assert forbidden not in haystack, 'draft or raw audit bytes were delivered'
            assert all(forbidden.encode() not in raw for raw in reads.values()), 'draft or raw audit bytes were readable'
        canaries_intact()
    except (AssertionError, KeyError, ValueError, OSError, IndexError, subprocess.SubprocessError) as failure:
        note('rejected', message=str(failure), stdin=payload)
        print(json.dumps({'type': 'result', 'is_error': True, 'result': 'fixture carrier rejection'}))
        return 71
    with Path(spec['sessions']).open('a') as session_log:
        session_log.write(session + '\n')
    note('work', stdin=payload, agent=agent, tools=tools)
    mode = spec.get('reply_mode', 'success')
    if spec.get('reject_work'):
        print(json.dumps({'type': 'result', 'is_error': True, 'result': 'fixture ordinary work rejected'}))
        return 72
    if mode == 'malformed':
        print('not one public JSON result')
        return 0
    result = {'type': 'result', 'is_error': False, 'result': audit(spec, reads), 'session_id': session,
              'modelUsage': {'fixture-aggregate-must-not-become-actual-id': {'inputTokens': 1}}}
    if mode == 'error-with-zero-exit':
        result['is_error'] = True
    elif mode == 'empty-result':
        result['result'] = '  '
    elif mode == 'wrong-session':
        result['session_id'] = spec['other_session_id']
    elif mode == 'not-json':
        result['result'] = 'The audit is described in prose, not returned as the original JSON object.'
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
