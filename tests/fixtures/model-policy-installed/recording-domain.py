#!/usr/bin/env python3
"""FIXTURE ONLY recording stand-in for the external `claude` executable (T-008 domain caller tests).

Separate from recording-claude.py so the spec/quality/WFI native branches stay byte-identical. It is not Claude
Code, not a model and never contacts a network, backend or credential store. It implements only the
non-interactive surface the real launcher and probe drive: `--help` (the T-007 HELP_TEXT vocabulary), a harmless
`--version`, and `-p` launches with the session/model/effort/agents/settings flags. Every tool attempt runs the
actual PreToolUse hook command from the generated --settings file with the actual tool input and honours its
decision; admitted Bash commands really run (cwd = the caller's cwd) and admitted files are really read. Events are
appended in assistant tool_use / user tool_result order to $HOME/.claude/projects/<cwd-slug>/<session>.jsonl and a
`--output-format json` wrapper is printed. A reused session exits 1 with the native error, no stdout and an
untouched transcript.

The formal record is the original domain reviewer schema (`domain-reviewer-a/v1` or `domain-reviewer-b/v1`,
stage `domain`): identities and the allowed_input_manifest are copied from the admitted invocation the launcher
really reserved, and the check ids/severities come from the CHECKS table of the installed
finalize-domain-review.py (read with ast.literal_eval, never executed). Every check is a fixture-only PASS carrying a
private marker finding, so no review judgement is claimed; it is delivery/configuration evidence only. Reading
--settings is owned launch configuration, not a model Read claim. RECORDING_CLAUDE_AUDIT names an owned JSONL audit
receiving argv, model/effort/agent, session and per-tool decision/command/path/hash metadata only; the environment
is never recorded.
"""
import ast
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import uuid

sys.dont_write_bytecode = True

HELP_TEXT = '\n'.join([
    'Usage: claude [options] [command] [prompt]',
    '',
    'Options:',
    '  --agent <agent>                       Agent for the current session.',
    '  --agents <json-or-file>               JSON object defining custom agents',
    '  --disallowedTools, --disallowed-tools <tools...>',
    '      Comma or space-separated list of tool names to deny',
    '  --effort <level>                      Effort level for the current session',
    '                                        (low, medium, high, xhigh, max)',
    '  --json-schema <schema>                JSON Schema for structured output',
    '  --model <model>                       Model for the current session.',
    '  --output-format <format>              Output format (only works with --print)',
    '  --permission-mode <mode>              Permission mode to use for the session',
    '  --plugin-dir <path>                   Load a plugin from a directory or .zip',
    '  -p, --print                           Print response and exit',
    '  --session-id <uuid>                   Use a specific session ID',
    '  --settings <file-or-json>             Path to a settings JSON file',
    '  --setting-sources <sources>          Comma-separated list of setting sources',
    '  --tools <tools...>                    Specify the list of available tools',
    ''])
VERSION = 'fixture-claude 1.0 (recording fixture; not Claude Code)'
VALUE_FLAGS = ('--session-id', '--model', '--effort', '--permission-mode', '--tools', '--disallowedTools',
               '--settings', '--setting-sources', '--agents', '--agent', '--output-format', '--plugin-dir',
               '--json-schema')
REQUIRED_FLAGS = ('--session-id', '--model', '--permission-mode', '--tools', '--settings', '--agents', '--agent',
                  '--output-format')
DIAGNOSTIC = 'Unreserved diagnostic, not a formal review.'
FORMAL = 'SDD independent '
READ_ORDER = 'Then Read each of these files with limit=1, in this order:'
FORMAL_READS = 'Read tool file_path values (canonical absolute paths):'
FORMAL_RESULT = 'Require exactly this result (one trailing newline allowed):'
ROLES = ('domain-reviewer-a', 'domain-reviewer-b')
FINALIZER = 'plugins/sdd-domain/scripts/finalize-domain-review.py'
PRIVATE = {'domain-reviewer-a': 'DOMAIN-A-PRIVATE-FINDING', 'domain-reviewer-b': 'DOMAIN-B-PRIVATE-FINDING'}
FINDING = ('FIXTURE ONLY: a deterministic recording CLI delivered this record; no model reviewed the domain '
           'artifacts. Private reviewer finding that must never cross the reviewer boundary.')


class Stop(Exception):
    """Fixture protocol failure: exit 2 with a message, never a wrapper."""


def sha(raw):
    return hashlib.sha256(raw if isinstance(raw, bytes) else raw.encode('utf-8')).hexdigest()


def domain_checks():
    """Role -> ordered (check id, severity floor) from the installed finalizer's CHECKS literal; nothing is executed."""
    path = Path(os.getcwd()) / FINALIZER
    if not path.is_file():
        raise Stop('installed domain finalizer is absent in the launch directory')
    for node in ast.parse(path.read_text(encoding='utf-8')).body:
        if isinstance(node, ast.Assign) and [t.id for t in node.targets if isinstance(t, ast.Name)] == ['CHECKS']:
            table = ast.literal_eval(node.value)
            return {'domain-reviewer-a': list(table['a'].items()), 'domain-reviewer-b': list(table['b'].items())}
    raise Stop('installed domain finalizer has no CHECKS table')


def audit(entry):
    path = os.environ.get('RECORDING_CLAUDE_AUDIT')
    if not path:
        raise Stop('RECORDING_CLAUDE_AUDIT is not configured')
    with open(path, 'a', encoding='utf-8') as stream:
        stream.write(json.dumps(entry, sort_keys=True) + '\n')


def parse(argv):
    options, rest, printing = {}, list(argv), False
    while rest:
        name = rest.pop(0)
        if name in ('-p', '--print') and not printing:
            printing = True
        elif name in VALUE_FLAGS and name not in options and rest:
            options[name] = rest.pop(0)
        else:
            raise Stop('unsupported fixture argument: ' + name[:64])
    if (not printing or not all(name in options for name in REQUIRED_FLAGS)
            or options['--output-format'] != 'json' or options['--permission-mode'] != 'dontAsk'):
        raise Stop('this fixture implements only non-interactive -p json dontAsk launches')
    if str(uuid.UUID(options['--session-id'])) != options['--session-id']:
        raise Stop('session ID is not a canonical UUID')
    agents = json.loads(options['--agents'])
    agent = agents.get(options['--agent']) if isinstance(agents, dict) else None
    if set(agents) != {options['--agent']} or not isinstance(agent, dict):
        raise Stop('--agents must define exactly the selected --agent')
    return options, agent


def settings_controls(path):
    """Owned launch configuration: the generated PreToolUse hook commands and permission allow rules."""
    settings = json.loads(Path(path).read_text(encoding='utf-8'))
    groups = settings.get('hooks', {}).get('PreToolUse', [])
    if not groups or any(group.get('matcher') != '*' for group in groups):
        raise Stop('generated settings must define catch-all PreToolUse hooks')
    hooks = [hook['command'] for group in groups for hook in group.get('hooks', [])
             if hook.get('type') == 'command' and isinstance(hook.get('command'), str)]
    if not hooks:
        raise Stop('generated settings define no PreToolUse hook command')
    return hooks, settings.get('permissions', {}).get('allow', [])


class Session:
    def __init__(self, options, agent, hooks, allow):
        self.session = options['--session-id']
        self.agent = options['--agent']
        self.cwd = os.getcwd()
        self.tools = set(options['--tools'].split(',')) & set(agent.get('tools', []))
        self.tools -= set(options.get('--disallowedTools', '').split(','))
        if '--json-schema' in options:
            self.tools.add('StructuredOutput')
        self.hooks, self.allow = hooks, allow
        self.transcript = (Path.home() / '.claude' / 'projects' / re.sub(r'[^A-Za-z0-9]', '-', self.cwd) /
                           (self.session + '.jsonl'))
        self.parent = None
        self.rows = 0
        self.outcomes = []
        self.reads = {}

    def row(self, kind, content):
        self.rows += 1
        identity = str(uuid.uuid5(uuid.NAMESPACE_URL, 'recording-claude:%s:%d' % (self.session, self.rows)))
        record = {'type': kind, 'sessionId': self.session, 'uuid': identity, 'parentUuid': self.parent,
                  'cwd': self.cwd, 'message': {'role': kind, 'content': content}}
        self.parent = identity
        self.transcript.parent.mkdir(parents=True, exist_ok=True)
        with open(self.transcript, 'a', encoding='utf-8') as stream:
            stream.write(json.dumps(record, ensure_ascii=False) + '\n')

    def hook(self, name, tool_input):
        """None when every actual hook admits the call, otherwise the denial reason."""
        event = json.dumps({'session_id': self.session, 'transcript_path': str(self.transcript), 'cwd': self.cwd,
                            'hook_event_name': 'PreToolUse', 'tool_name': name, 'tool_input': tool_input})
        for command in self.hooks:
            result = subprocess.run(['bash', '-c', command], input=event, text=True, capture_output=True,
                                    cwd=self.cwd, timeout=60, check=False)
            if result.returncode != 0:  # fixture choice: any hook failure blocks (fail closed)
                return result.stderr.strip() or 'PreToolUse hook failed'
            if result.stdout.strip():
                try:
                    decision = json.loads(result.stdout).get('hookSpecificOutput', {})
                except (ValueError, AttributeError):
                    return 'PreToolUse hook returned malformed output'
                if decision.get('permissionDecision') != 'allow':
                    return decision.get('permissionDecisionReason') or 'PreToolUse hook denied the call'
        return None

    def call(self, name, tool_input):
        if name not in self.tools:
            raise Stop('tool is not available in this launch: ' + name)
        tool_id = 'toolu_fixture_' + sha('%s:%d' % (self.session, len(self.outcomes)))[:24]
        self.row('assistant', [{'type': 'tool_use', 'id': tool_id, 'name': name, 'input': tool_input}])
        reason = self.hook(name, tool_input)
        # dontAsk: Bash also needs an exact settings allow rule; Read/StructuredOutput are not permission-gated here.
        if reason is None and name == 'Bash' and 'Bash(' + tool_input['command'] + ')' not in self.allow:
            reason = 'Permission to use Bash was denied: no exact permissions.allow rule.'
        outcome = {'tool': name, 'decision': 'allow' if reason is None else 'deny'}
        if name == 'Bash':
            outcome['command'] = tool_input['command']
        elif name == 'Read':
            outcome['path'] = tool_input['file_path']
        if reason is not None:
            content, error = reason, True
        elif name == 'Bash':
            result = subprocess.run(['bash', '-c', tool_input['command']], cwd=self.cwd, text=True,
                                    capture_output=True, stdin=subprocess.DEVNULL, timeout=300, check=False)
            content, error = result.stdout + result.stderr, result.returncode != 0
            outcome['output_sha256'] = sha(content)
        elif name == 'Read':
            path = Path(tool_input['file_path'])
            if not path.is_absolute():
                raise Stop('Read requires an absolute file_path')
            try:
                raw = path.read_bytes()
            except OSError:
                content, error = 'File could not be read.', True
            else:
                self.reads[str(path)] = raw
                lines = raw.decode('utf-8', errors='replace').splitlines()[:tool_input.get('limit')]
                content = '\n'.join('%6d\t%s' % (index, line) for index, line in enumerate(lines, 1))
                error = False
                outcome['sha256'] = sha(raw)
        else:
            content, error = 'Structured output provided successfully', False
        outcome['is_error'] = error
        self.row('user', [{'type': 'tool_result', 'tool_use_id': tool_id, 'content': content, 'is_error': error}])
        self.outcomes.append(outcome)
        return content, error


def diagnostic(run, prompt):
    """The probe's exact serial calls: hashes, sampled reads, the chained Bash, the outside Read, then output."""
    lines = prompt.split('\n')
    hashes = [match[1] for line in lines if (match := re.fullmatch(r'[0-9]+\. Bash (.+)', line))]
    if not hashes or READ_ORDER not in lines:
        raise Stop('unrecognized diagnostic prompt')
    start = lines.index(READ_ORDER) + 1
    end = next((index for index in range(start, len(lines)) if lines[index].startswith('Then Bash ')), None)
    final = [line[len('Finally Read '):] for line in lines if line.startswith('Finally Read ')]
    if end is None or end == start or len(final) != 1:
        raise Stop('unrecognized diagnostic prompt')
    for command in hashes:
        run.call('Bash', {'command': command})
    for path in lines[start:end]:
        run.call('Read', {'file_path': path, 'limit': 1})
    run.call('Bash', {'command': lines[end][len('Then Bash '):]})
    run.call('Read', {'file_path': final[0]})
    if 'StructuredOutput' not in run.tools:
        raise Stop('this fixture implements only the JSON domain review stage')
    report = {'checks': [{'id': 'call-%d' % index, 'status': 'ran' if item['decision'] == 'allow' else 'denied'}
                         for index, item in enumerate(run.outcomes, 1)]}
    run.call('StructuredOutput', report)
    return report


def formal(run, prompt, role):
    """Pinned verifier first and checked, then every listed Read, then the fixture-only original domain role JSON."""
    lines = prompt.split('\n')
    commands = re.findall(r'```sh\n(.*?)\n```', prompt, re.S)
    if len(commands) != 1 or FORMAL_READS not in lines or FORMAL_RESULT not in lines:
        raise Stop('unrecognized formal prompt')
    paths = json.loads(lines[lines.index(FORMAL_READS) + 1])
    expected = lines[lines.index(FORMAL_RESULT) + 1]
    content, error = run.call('Bash', {'command': commands[0]})
    if error or content not in (expected, expected + '\n'):
        raise Stop('launch-control verification failed; stopping without a verdict')
    for path in paths:
        if run.call('Read', {'file_path': path})[1]:
            raise Stop('admitted Read failed; stopping without a verdict')
    invocation = json.loads(run.reads[paths[0]])
    if (role not in ROLES or invocation.get('role') != role or invocation.get('run_id') != run.session
            or invocation.get('host_session_id') != run.session or invocation.get('stage') != 'domain'
            or 'StructuredOutput' not in run.tools):
        raise Stop('invocation identity differs from this launch or the role is not a domain reviewer')
    output = {'schema': role + '/v1', 'stage': 'domain', 'role': role, 'run_id': run.session,
              'host_session_id': run.session, 'allowed_input_manifest': invocation['allowed_input_manifest'],
              'verdict': 'PASS',
              'checks': [{'id': check, 'result': 'PASS', 'severity': floor, 'finding': PRIVATE[role] + ': ' + FINDING}
                         for check, floor in domain_checks()[role]]}
    if run.call('StructuredOutput', output)[1]:
        raise Stop('StructuredOutput was denied')
    return output


def main(argv):
    if argv == ['--help']:
        audit({'mode': 'help'})
        sys.stdout.write(HELP_TEXT)
        return 0
    if argv == ['--version']:
        audit({'mode': 'version'})
        print(VERSION)
        return 0
    options, agent = parse(argv)
    session = options['--session-id']
    entry = {'argv': argv, 'session_id': session, 'model': options['--model'], 'effort': options.get('--effort'),
             'agent': options['--agent'], 'agent_model': agent.get('model'), 'agent_effort': agent.get('effort')}
    projects = Path.home() / '.claude' / 'projects'
    if projects.is_dir() and any(projects.rglob(session + '.jsonl')):
        audit(dict(entry, mode='collision'))
        sys.stderr.write('Error: Session ID ' + session + ' is already in use.\n')
        return 1
    prompt = sys.stdin.buffer.read().decode('utf-8')
    run = Session(options, agent, *settings_controls(options['--settings']))
    if prompt.startswith(DIAGNOSTIC):
        mode = 'diagnostic'
    elif prompt.startswith(FORMAL):
        mode = 'formal'
    else:
        raise Stop('unrecognized prompt; only the launcher and probe protocol is implemented')
    run.row('user', prompt)
    output = diagnostic(run, prompt) if mode == 'diagnostic' else formal(run, prompt, options['--agent'])
    audit(dict(entry, mode=mode, tools=run.outcomes, transcript_sha256=sha(run.transcript.read_bytes())))
    wrapper = {'type': 'result', 'subtype': 'success', 'is_error': False, 'session_id': session,
               'num_turns': len(run.outcomes) + 1, 'result': json.dumps(output, sort_keys=True),
               'structured_output': output}
    sys.stdout.write(json.dumps(wrapper, sort_keys=True) + '\n')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main(sys.argv[1:]))
    except (Stop, ValueError, KeyError, TypeError, AttributeError, OSError, subprocess.SubprocessError) as failure:
        sys.stderr.write('recording-domain fixture stopped: ' + str(failure)[:512] + '\n')
        sys.exit(2)
