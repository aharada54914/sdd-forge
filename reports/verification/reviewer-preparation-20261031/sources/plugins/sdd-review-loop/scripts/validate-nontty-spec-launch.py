#!/usr/bin/env python3
"""Read-only spec/impl proof for caller-proposed non-TTY Claude IDs.

This does not reserve an identity or approve a review verdict. The normal
review-context validator still owns reservation and output schema checks.
"""
import argparse
from collections.abc import Mapping
from contextlib import contextmanager
from contextvars import ContextVar
from functools import wraps
import importlib.util
import hashlib
import json
import os
import pathlib
import re
import shlex
import signal
import shutil
import stat
import subprocess
import sys
import tempfile
import uuid
from typing import Any


STAGE_ROLES = {
    'spec': ('spec-reviewer-a', 'spec-reviewer-b'),
    'impl': ('impl-reviewer-a', 'impl-reviewer-b'),
    'task': ('task-reviewer-a', 'task-reviewer-b'),
    'quality': ('sdd-evaluator',),
    'domain': ('domain-reviewer-a', 'domain-reviewer-b'),
}
JSON_REVIEW_STAGES = ('spec', 'impl', 'task', 'domain')
DOMAIN_FEATURE = 'sdd-domain-model'
STRUCTURED_OUTPUT_ENFORCE_TURN = ('[structured-output-enforce] You MUST call the '
                                  'StructuredOutput tool to complete this request. '
                                  'Call this tool now.')


def admitted_raw_hashes(root, data, fixed_inputs=None):
    """Keep raw transport observations separate from canonical task normalization."""
    entries = data['allowed_input_manifest']
    selected = {e['path'] for e in fixed_inputs['inventory']['inputs']} if fixed_inputs else set()
    def source(name):
        return (pathlib.Path(fixed_inputs['snapshot']) if name in selected else root) / name
    actual = {e['path']: sha(source(e['path'])) for e in entries}
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
        command = ['rtk', 'proxy', 'bash', str(root /
            'plugins/sdd-review-loop/scripts/task-review-precheck.sh'), feature,
            match[1], match[2], '--verify-inputs']
        if fixed_inputs:
            command.extend(['--fixed-input-record', fixed_inputs['record'],
                            '--fixed-input-snapshot', fixed_inputs['snapshot']])
        result = subprocess.run(command, cwd=root,
            text=True, capture_output=True, timeout=600)
        require(result.returncode == 0, 'canonical normalized task verification failed')
        require(all(sha(source(e['path'])) == actual[e['path']] for e in entries),
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


# ---- Selected-model launch binding (T-007). Absent controls keep every legacy path exact. ----

MODEL_POLICY_HELPER = 'plugins/sdd-implementation/scripts/model-policy.py'
TRUSTED_MODEL_RUNTIME = tuple(sorted((
    MODEL_POLICY_HELPER, 'plugins/sdd-implementation/scripts/select-agent-model.sh',
    'plugins/sdd-implementation/scripts/select-agent-model.ps1',
    'contracts/agent-model-capabilities.v2.json', 'contracts/model-policy.v1.json',
    'contracts/model-launch-controls.schema.json')))
# Protected transport role -> trusted policy role; the host is fixed for this transport.
MODEL_ROLES = {role: role for stage in JSON_REVIEW_STAGES for role in STAGE_ROLES[stage]}
MODEL_ROLES['sdd-evaluator'] = 'evaluator'
MODEL_HOST = 'claude-code'
MODEL_TRANSPORT = 'claude-print'
EFFORT_CARRIER = 'flag+frontmatter'
MODEL_LAUNCH_RECORD = 'model-launch.json'
MODEL_REASONS = frozenset((
    'config-invalid', 'config-conflict', 'native-precedence-conflict', 'discovery-unavailable',
    'discovery-incomplete', 'discovery-stale', 'scope-mismatch', 'model-unavailable', 'model-unverified',
    'model-tier-unavailable', 'effort-unavailable', 'budget-unverifiable', 'resume-conflict',
    'actual-id-unavailable', 'actual-id-mismatch', 'input-invalid'))
VALIDATION_FIELDS = frozenset(('schema', 'controls', 'pins', 'trusted', 'role', 'host', 'run_id',
                               'session_id', 'attempt', 'require_actual_id', 'selection'))
BINDING_FIELDS = VALIDATION_FIELDS | {'transport_role', 'native_model', 'effort', 'effort_control',
                                      'native_overrides'}
LAUNCH_FIELDS = (VALIDATION_FIELDS - {'selection'}) | {
    'transport_role', 'selection_sha256', 'native_model', 'effort', 'effort_control', 'effort_carrier',
    'native_alignment', 'transport', 'argv', 'argv_sha256', 'model_argv', 'effort_argv',
    'agent_model', 'agent_effort', 'native_overrides'}
# Documented Claude settings that can override our explicit carriers; only their values are kept.
NATIVE_OVERRIDES = ('ANTHROPIC_MODEL', 'ANTHROPIC_DEFAULT_HAIKU_MODEL',
                    'ANTHROPIC_DEFAULT_SONNET_MODEL', 'ANTHROPIC_DEFAULT_OPUS_MODEL',
                    'CLAUDE_CODE_SUBAGENT_MODEL', 'CLAUDE_CODE_SUBAGENT_MODEL_FORCE',
                    'CLAUDE_CODE_EFFORT_LEVEL')
FORCE_TRUE = ('1', 'true', 'yes', 'on')
FORCE_FALSE = ('0', 'false', 'no', 'off')
ALIAS_REMAPS = {'opus': 'ANTHROPIC_DEFAULT_OPUS_MODEL', 'sonnet': 'ANTHROPIC_DEFAULT_SONNET_MODEL',
                'haiku': 'ANTHROPIC_DEFAULT_HAIKU_MODEL'}
SELECTED_EFFORTS = ('low', 'medium', 'high', 'xhigh')
MODEL_ID = re.compile(r'[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}')
SHA256 = re.compile(r'[0-9a-f]{64}')
_CONTROL_COMPONENT = r'[^/\\:\x00-\x1f\x7f]{0,254}[^/\\:\x00-\x1f\x7f. ]'
CONTROL_PATH = re.compile(_CONTROL_COMPONENT + '(?:/' + _CONTROL_COMPONENT + ')*')
MAX_CONTROLS_OUTPUT = 16 * 1024 * 1024
MAX_CONTROLS_ERROR = 65536
MAX_LAUNCH_RECORD = 16 * 1024 * 1024
CONTROLS_TIMEOUT = 120


class ModelLaunchError(ValueError):
    """Typed selected-launch rejection using the model-policy-error/v1 reason vocabulary."""

    def __init__(self, reason, message):
        if reason not in MODEL_REASONS:
            reason = 'input-invalid'
        super().__init__(reason + ': ' + message)
        self.reason = reason


def model_require(ok, reason, message):
    if not ok:
        raise ModelLaunchError(reason, message)


def canonical_bytes(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=False,
                      allow_nan=False).encode('utf-8')


def strict_document(raw, label):
    """One strict UTF-8 JSON object: no duplicate keys or nonfinite numbers."""
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError('duplicate JSON key')
            result[key] = value
        return result

    def nonfinite(_value):
        raise ValueError('nonfinite JSON number')
    try:
        value = json.loads(raw.decode('utf-8'), object_pairs_hook=unique, parse_constant=nonfinite)
    except (UnicodeDecodeError, ValueError, RecursionError):
        raise ModelLaunchError('input-invalid', label + ' is not one strict JSON object') from None
    model_require(isinstance(value, dict), 'input-invalid', label + ' is not one strict JSON object')
    return value


def control_path_text(value):
    """Exact relative controls path text; normalization must never authorize a dot or separator alias."""
    if isinstance(value, pathlib.PurePath):
        model_require(not value.is_absolute(), 'input-invalid', 'model controls path must be relative')
        value = value.as_posix()
    model_require(isinstance(value, str) and len(value) <= 1024 and
                  CONTROL_PATH.fullmatch(value) is not None,
                  'input-invalid', 'model controls require a canonical relative path')
    return value


def captured_environment(environment=None):
    """Private child environment snapshot: an explicit mapping wins, otherwise the current context."""
    source = os.environ if environment is None else environment
    model_require(isinstance(source, Mapping) and
                  all(isinstance(k, str) and isinstance(v, str) for k, v in source.items()),
                  'input-invalid', 'launch environment must map strings to strings')
    return dict(source)


def native_overrides(environment):
    """Only the closed documented override values; never the rest of the environment."""
    return {name: environment.get(name) for name in NATIVE_OVERRIDES}


def require_native_precedence(native_model, effort, overrides):
    """Documented Claude precedence over --model/--effort and the generated agent (configuration only)."""
    level = overrides['CLAUDE_CODE_EFFORT_LEVEL']
    model_require(not level or level == effort, 'native-precedence-conflict',
                  'CLAUDE_CODE_EFFORT_LEVEL overrides the selected effort')
    force = (overrides['CLAUDE_CODE_SUBAGENT_MODEL_FORCE'] or '').lower()
    model_require(not force or force in FORCE_TRUE + FORCE_FALSE, 'native-precedence-conflict',
                  'CLAUDE_CODE_SUBAGENT_MODEL_FORCE has an undocumented value')
    forced = overrides['CLAUDE_CODE_SUBAGENT_MODEL']
    model_require(force not in FORCE_TRUE or not forced or forced == native_model,
                  'native-precedence-conflict', 'forced subagent model differs from the selected model')
    remap = ALIAS_REMAPS.get(native_model)
    model_require(remap is None or not overrides[remap], 'native-precedence-conflict',
                  'selected model alias is remapped; its exact native binding is unverifiable')


def installed_model_runtime_root():
    """Installed CLI authority comes only from this module's canonical source location."""
    return pathlib.Path(__file__).resolve(strict=True).parents[3]


def model_launch_controls(root, role, run_id, session_id, controls, controls_sha256, environment, *,
                          host=MODEL_HOST, runtime_root=None):
    """Run the trusted helper's public launch-controls boundary; bounded closed output only."""
    runtime_root = root if runtime_root is None else pathlib.Path(runtime_root)
    helper = runtime_root / MODEL_POLICY_HELPER
    parts = pathlib.PurePosixPath(MODEL_POLICY_HELPER).parts
    model_require(helper.is_file() and not any(runtime_root.joinpath(*parts[:index]).is_symlink()
                                                for index in range(1, len(parts) + 1)),
                  'input-invalid', 'trusted model-policy helper is missing or symlinked')
    command = [sys.executable, '-I', '-B', str(helper), 'launch-controls', '--controls', controls,
               '--controls-sha256', controls_sha256, '--role', role, '--host', host,
               '--run-id', run_id, '--session-id', session_id]
    try:
        with tempfile.TemporaryFile() as output, tempfile.TemporaryFile() as errors:
            result = subprocess.run(command, cwd=root, env=dict(environment), stdin=subprocess.DEVNULL,
                                    stdout=output, stderr=errors, timeout=CONTROLS_TIMEOUT, check=False)
            model_require(output.seek(0, os.SEEK_END) <= MAX_CONTROLS_OUTPUT and
                          errors.seek(0, os.SEEK_END) <= MAX_CONTROLS_ERROR,
                          'input-invalid', 'launch-controls output exceeds its bound')
            output.seek(0)
            errors.seek(0)
            raw, diagnostic = output.read(), errors.read()
    except (OSError, subprocess.TimeoutExpired):
        raise ModelLaunchError('input-invalid', 'trusted launch-controls did not complete') from None
    if result.returncode == 2 and not raw:
        error = strict_document(diagnostic, 'launch-controls error')
        model_require(diagnostic == canonical_bytes(error) + b'\n' and
                      set(error) == {'schema', 'reason', 'message'} and
                      error['schema'] == 'model-policy-error/v1' and error['reason'] in MODEL_REASONS and
                      isinstance(error['message'], str) and 0 < len(error['message']) <= 512,
                      'input-invalid', 'launch-controls error is not one closed typed error')
        raise ModelLaunchError(error['reason'], error['message'])
    model_require(result.returncode == 0 and not diagnostic, 'input-invalid',
                  'launch-controls failed without a typed error')
    value = strict_document(raw, 'launch-controls validation')
    model_require(raw == canonical_bytes(value) + b'\n', 'input-invalid',
                  'launch-controls validation is not canonical')
    return value


def checked_controls_validation(value, *, role, run_id, session_id, controls, controls_sha256, host=MODEL_HOST):
    """Closed model-launch-validation/v1 for this actual invocation; the helper owns eligibility."""
    def references(entries):
        return (isinstance(entries, list) and all(
            isinstance(e, dict) and set(e) == {'path', 'sha256'} and isinstance(e['path'], str) and
            CONTROL_PATH.fullmatch(e['path']) is not None and isinstance(e['sha256'], str) and
            SHA256.fullmatch(e['sha256']) is not None for e in entries) and
            [e['path'] for e in entries] == sorted({e['path'] for e in entries}))
    model_require(isinstance(value, dict) and set(value) == VALIDATION_FIELDS and
                  value['schema'] == 'model-launch-validation/v1' and
                  value['controls'] == {'path': controls, 'sha256': controls_sha256} and
                  references(value['pins']) and bool(value['pins']) and
                  controls not in {e['path'] for e in value['pins']} and
                  references(value['trusted']) and
                  tuple(e['path'] for e in value['trusted']) == TRUSTED_MODEL_RUNTIME and
                  value['role'] == role and value['host'] == host and
                  value['run_id'] == run_id and value['session_id'] == session_id and
                  type(value['attempt']) is int and value['attempt'] > 0 and
                  value['require_actual_id'] is False,
                  'input-invalid', 'launch-controls validation differs from this invocation')
    selection = value['selection']
    resolved = selection.get('resolved') if isinstance(selection, dict) else None
    model_require(isinstance(resolved, dict) and selection.get('schema') == 'model-selection/v1' and
                  selection.get('role') == role and selection.get('host') == host and
                  selection.get('binding') == {'run_id': run_id, 'session_id': session_id,
                                               'attempt': value['attempt']} and
                  set(resolved) == {'catalog_id', 'native_id', 'effort', 'effort_control'} and
                  isinstance(resolved['native_id'], str) and
                  MODEL_ID.fullmatch(resolved['native_id']) is not None and
                  resolved['effort'] in SELECTED_EFFORTS and isinstance(resolved['effort_control'], str) and
                  selection.get('selection_sha256') == hashlib.sha256(canonical_bytes(
                      {k: v for k, v in selection.items() if k != 'selection_sha256'})).hexdigest(),
                  'input-invalid', 'launch-controls selection is not bound to this invocation')
    return value


def derived_model_binding(validation, transport_role, environment):
    resolved = validation['selection']['resolved']
    binding = dict(validation, transport_role=transport_role, native_model=resolved['native_id'],
                   effort=resolved['effort'], effort_control=resolved['effort_control'],
                   native_overrides=native_overrides(environment))
    require_native_precedence(binding['native_model'], binding['effort'], binding['native_overrides'])
    return binding


def model_launch_binding(root, data, controls_path, raw_sha, *, environment=None):
    """Fresh trusted controls validation for this invocation plus captured native override values."""
    root = pathlib.Path(root)
    environment = captured_environment(environment)
    transport_role = data.get('role')
    model_require(transport_role in MODEL_ROLES and
                  transport_role in STAGE_ROLES.get(data.get('stage'), ()),
                  'scope-mismatch', 'invocation role has no protected model-policy role')
    session_id = data.get('host_session_id')
    # A present run_id is authoritative and validated; only an absent key uses the legacy alias.
    run_id = data['run_id'] if 'run_id' in data else session_id
    model_require(all(isinstance(value, str) and MODEL_ID.fullmatch(value) is not None
                      for value in (run_id, session_id)),
                  'input-invalid', 'invocation run or session identity is invalid')
    controls = control_path_text(controls_path)
    model_require(isinstance(raw_sha, str) and SHA256.fullmatch(raw_sha) is not None,
                  'input-invalid', 'model controls require a lowercase raw SHA-256 pin')
    entries = data.get('allowed_input_manifest')
    model_require(isinstance(entries, list) and all(isinstance(e, dict) for e in entries),
                  'input-invalid', 'invocation input manifest is invalid')
    substantive = {entry.get('path') for entry in entries}
    model_require(controls not in substantive, 'input-invalid',
                  'model controls must never be a reviewer input')
    role = MODEL_ROLES[transport_role]
    validation = checked_controls_validation(
        model_launch_controls(root, role, run_id, session_id, controls, raw_sha, environment),
        role=role, run_id=run_id, session_id=session_id, controls=controls, controls_sha256=raw_sha)
    overlap = sorted({entry['path'] for entry in validation['pins']} & substantive)
    model_require(not overlap, 'input-invalid',
                  'model control pins overlap reviewer inputs: ' + ', '.join(overlap)[:256])
    return derived_model_binding(validation, transport_role, environment)


def checked_model_binding(binding):
    controls = binding.get('controls') if isinstance(binding, dict) else None
    model_require(isinstance(binding, dict) and set(binding) == BINDING_FIELDS and
                  isinstance(controls, dict) and set(controls) == {'path', 'sha256'} and
                  isinstance(binding['transport_role'], str) and binding['transport_role'] in MODEL_ROLES and
                  MODEL_ROLES[binding['transport_role']] == binding['role'] and
                  isinstance(binding['native_overrides'], dict) and
                  set(binding['native_overrides']) == set(NATIVE_OVERRIDES) and
                  isinstance(binding['native_model'], str) and binding['effort'] in SELECTED_EFFORTS,
                  'input-invalid', 'model binding is not a closed selected launch binding')
    return binding


def fresh_model_binding(root, binding, environment):
    """Recompute through the public helper; a resealed caller binding is never authority."""
    checked_model_binding(binding)
    model_require(native_overrides(environment) == binding['native_overrides'],
                  'native-precedence-conflict', 'captured native overrides differ from the validated binding')
    require_native_precedence(binding['native_model'], binding['effort'], binding['native_overrides'])
    controls = control_path_text(binding['controls']['path'])
    digest = binding['controls']['sha256']
    model_require(isinstance(digest, str) and SHA256.fullmatch(digest) is not None and
                  isinstance(binding['run_id'], str) and MODEL_ID.fullmatch(binding['run_id']) is not None and
                  isinstance(binding['session_id'], str) and
                  MODEL_ID.fullmatch(binding['session_id']) is not None,
                  'input-invalid', 'model binding identity or controls pin is invalid')
    validation = checked_controls_validation(
        model_launch_controls(pathlib.Path(root), binding['role'], binding['run_id'],
                              binding['session_id'], controls, digest, environment),
        role=binding['role'], run_id=binding['run_id'], session_id=binding['session_id'],
        controls=controls, controls_sha256=digest)
    fresh = derived_model_binding(validation, binding['transport_role'], environment)
    model_require(canonical_bytes(fresh) == canonical_bytes(binding), 'config-conflict',
                  'model binding differs from fresh controls validation')
    return fresh


def selected_argv(command, binding):
    """Model/effort carriers actually present in the exact selected argv."""
    model_require(isinstance(command, list) and all(isinstance(part, str) for part in command) and
                  command[:2] == ['rtk', 'proxy'] and command[3:4] == ['-p'],
                  'input-invalid', 'selected argv is not the fixed claude print transport')

    def value(flag):
        model_require(command.count(flag) == 1 and command.index(flag) + 1 < len(command),
                      'native-precedence-conflict', 'selected argv must carry exactly one ' + flag)
        return command[command.index(flag) + 1]
    model, effort, agent = value('--model'), value('--effort'), value('--agent')
    model_require(value('--setting-sources') == '', 'native-precedence-conflict',
                  'selected argv must exclude user, project and local settings')
    agents = strict_document(value('--agents').encode('utf-8'), 'generated --agents definition')
    definition = agents.get(agent)
    model_require(set(agents) == {agent} and isinstance(definition, dict), 'native-precedence-conflict',
                  'generated --agents must define exactly the selected agent')
    model_require(agent == binding['transport_role'] and model == binding['native_model'] and
                  effort == binding['effort'] and definition.get('model') == model and
                  definition.get('effort') == effort, 'native-precedence-conflict',
                  'selected argv or generated agent model/effort differs from the selection')
    return {'model_argv': ['--model', model], 'effort_argv': ['--effort', effort],
            'agent_model': definition['model'], 'agent_effort': definition['effort']}


def model_launch_document(binding, command, native_alignment):
    checked_model_binding(binding)
    model_require(native_alignment in ('matching', 'generated'), 'input-invalid',
                  'native alignment must be matching or generated')
    carriers = selected_argv(command, binding)
    document = {key: binding[key] for key in ('controls', 'pins', 'trusted', 'role', 'transport_role',
                                              'host', 'run_id', 'session_id', 'attempt',
                                              'require_actual_id', 'native_model', 'effort',
                                              'effort_control', 'native_overrides')}
    document.update(carriers, schema='model-launch-binding/v1',
                    selection_sha256=binding['selection']['selection_sha256'],
                    effort_carrier=EFFORT_CARRIER, native_alignment=native_alignment,
                    transport=MODEL_TRANSPORT, argv=list(command),
                    argv_sha256=hashlib.sha256(canonical_bytes(list(command))).hexdigest())
    return document



_PROTECTED_OUTPUT: ContextVar[dict[pathlib.Path, int] | None] = ContextVar('protected_output', default=None)


@contextmanager
def safe_output_directory(path):
    """Hold an existing canonical directory without following any ancestor alias."""
    path = pathlib.Path(path)
    required = ('O_NOFOLLOW', 'O_DIRECTORY', 'O_NONBLOCK')
    model_require(path.is_absolute() and '..' not in path.parts and
                  all(isinstance(getattr(os, name, None), int) for name in required) and
                  os.open in os.supports_dir_fd and os.mkdir in os.supports_dir_fd and
                  os.listdir in os.supports_fd,
                  'input-invalid', 'safe protected output primitives are unavailable')
    flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY | os.O_NONBLOCK | getattr(os, 'O_CLOEXEC', 0)
    descriptors = []
    try:
        current = os.open(path.anchor, flags)
        descriptors.append(current)
        for part in path.parts[1:]:
            model_require(part in os.listdir(current), 'input-invalid', 'output directory is not canonical')
            current = os.open(part, flags, dir_fd=current)
            descriptors.append(current)
        yield current
    except OSError:
        raise ModelLaunchError('input-invalid', 'protected output directory is unsafe') from None
    finally:
        for descriptor in reversed(descriptors):
            os.close(descriptor)


def output_directory_identity(path, descriptor):
    with safe_output_directory(path) as current:
        left, right = os.fstat(current), os.fstat(descriptor)
        model_require((left.st_dev, left.st_ino) == (right.st_dev, right.st_ino),
                      'input-invalid', 'protected output directory changed')


@contextmanager
def protected_output_scope(output):
    output = pathlib.Path(output)
    with safe_output_directory(output.parent) as parent:
        directories = {output.parent: parent}
        token = _PROTECTED_OUTPUT.set(directories)
        try:
            yield
        finally:
            _PROTECTED_OUTPUT.reset(token)
            owned = [(path, descriptor) for path, descriptor in directories.items() if path != output.parent]
            directories.clear()
            for _, descriptor in owned:
                os.close(descriptor)



def protected_launch_output(function):
    @wraps(function)
    def scoped(root, invocation, output, manifest_sha256=None, *,
               fixed_input_record=None, fixed_input_snapshot=None, model_binding=None):
        if model_binding is None:
            return function(root, invocation, output, manifest_sha256,
                            fixed_input_record=fixed_input_record, fixed_input_snapshot=fixed_input_snapshot)
        with protected_output_scope(output):
            return function(root, invocation, output, manifest_sha256,
                            fixed_input_record=fixed_input_record, fixed_input_snapshot=fixed_input_snapshot,
                            model_binding=model_binding)
    return scoped


def protected_output_directories():
    directories = _PROTECTED_OUTPUT.get()
    model_require(directories is None or bool(directories), 'input-invalid', 'protected output scope is closed')
    return directories


def create_launch_output(output):
    directories = protected_output_directories()
    if directories is None:
        output.mkdir()
        return
    model_require(output.parent in directories, 'input-invalid', 'output parent is not held')
    parent = directories[output.parent]
    output_directory_identity(output.parent, parent)
    try:
        os.mkdir(output.name, mode=0o700, dir_fd=parent)
        descriptor = os.open(output.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY |
                             os.O_NONBLOCK | getattr(os, 'O_CLOEXEC', 0), dir_fd=parent)
    except OSError:
        raise ModelLaunchError('input-invalid', 'protected output could not be exclusively created') from None
    directories[output] = descriptor
    output_directory_identity(output, descriptor)


def check_launch_output():
    directories = protected_output_directories()
    if directories is not None:
        for path, descriptor in directories.items():
            output_directory_identity(path, descriptor)


@contextmanager
def model_output_directory(output, directory_fd=None):
    output = pathlib.Path(output)
    directories = protected_output_directories()
    if directory_fd is None and directories is not None:
        model_require(output in directories, 'input-invalid', 'model output is not held')
        directory_fd = directories[output]
    if directory_fd is None:
        with safe_output_directory(output) as descriptor:
            yield descriptor
    else:
        output_directory_identity(output, directory_fd)
        yield directory_fd


def write_launch_bytes(path, raw, *, exclusive=False, unchanged=False):
    """Selected launch writes stay anchored; default callers keep their original behavior."""
    directories = protected_output_directories()
    if directories is None:
        with path.open('xb' if exclusive else 'wb') as stream:
            stream.write(raw)
        return
    model_require(path.parent in directories, 'input-invalid', 'launch artifact directory is not held')
    descriptor = directories[path.parent]
    output_directory_identity(path.parent, descriptor)
    if unchanged:
        model_require(read_regular(path, MAX_LAUNCH_RECORD, 'unchanged launch artifact') == raw,
                      'input-invalid', 'launch artifact changed before repeated publication')
        return
    write_model_bytes(path.parent, path.name, raw, directory_fd=descriptor)


def write_launch_text(path, text, *, exclusive=False, unchanged=False):
    if protected_output_directories() is None:
        if exclusive:
            with path.open('x', encoding='utf-8') as stream:
                stream.write(text)
        else:
            path.write_text(text)
        return
    write_launch_bytes(path, text.encode(), exclusive=exclusive, unchanged=unchanged)


def record_model_launch(output, binding, command, native_alignment):
    """Create-only prelaunch binding of the exact selected argv; returns its raw SHA-256."""
    raw = canonical_bytes(model_launch_document(binding, command, native_alignment))
    with model_output_directory(output) as descriptor:
        write_model_bytes(pathlib.Path(output), MODEL_LAUNCH_RECORD, raw, directory_fd=descriptor)
    return hashlib.sha256(raw).hexdigest()


def read_regular(path, limit, label, *, digest_only=False):
    """Capture bounded regular bytes through descriptor-relative, exact no-follow components."""
    nofollow = getattr(os, 'O_NOFOLLOW', None)
    directory = getattr(os, 'O_DIRECTORY', None)
    nonblocking = getattr(os, 'O_NONBLOCK', None)
    if (not isinstance(nofollow, int) or not isinstance(directory, int) or
            not isinstance(nonblocking, int) or os.open not in os.supports_dir_fd or
            os.listdir not in os.supports_fd):
        raise ModelLaunchError('input-invalid',
                               'this runtime cannot safely capture ' + label + ' components')
    path = pathlib.Path(path).absolute()
    parts = path.parts[1:]
    model_require(bool(parts) and all(part not in ('.', '..') for part in parts),
                  'input-invalid', label + ' path is not canonical')
    descriptors = []
    try:
        base = os.open(path.anchor, os.O_RDONLY | nofollow | directory)
        descriptors.append(base)
        for index, part in enumerate(parts):
            model_require(part in os.listdir(base), 'input-invalid',
                          label + ' has a missing or noncanonical path component')
            flags = os.O_RDONLY | nofollow | nonblocking | getattr(os, 'O_CLOEXEC', 0)
            if index < len(parts) - 1:
                flags |= directory
            descriptor = os.open(part, flags, dir_fd=base)
            descriptors.append(descriptor)
            base = descriptor
        descriptor = descriptors[-1]
        status = os.fstat(descriptor)
        model_require(stat.S_ISREG(status.st_mode) and status.st_size <= limit, 'input-invalid',
                      label + ' is not a bounded regular file')
        chunks: list[bytes] = []
        digest = hashlib.sha256() if digest_only else None
        size = 0
        while True:
            chunk = os.read(descriptor, min(65536, limit + 1 - size))
            if not chunk:
                return digest.hexdigest() if digest is not None else b''.join(chunks)
            if digest is not None:
                digest.update(chunk)
            else:
                chunks.append(chunk)
            size += len(chunk)
            model_require(size <= limit, 'input-invalid', label + ' exceeds its bound')
    except OSError:
        raise ModelLaunchError('input-invalid', label + ' could not be read') from None
    finally:
        for descriptor in reversed(descriptors):
            os.close(descriptor)


def role_definition_path(transport_role):
    if transport_role in STAGE_ROLES['domain']:
        return 'plugins/sdd-domain/agents/' + transport_role + '.md'
    return ('plugins/sdd-quality-loop/agents/evaluator.md' if transport_role == 'sdd-evaluator' else
            'plugins/sdd-review-loop/agents/' + transport_role + '.md')


def role_frontmatter_alignment(frontmatter, native_model, effort):
    """One unambiguous trusted model is required, effort is optional; both must match to be 'matching'."""
    lines = frontmatter.splitlines()
    models = [line for line in lines if re.match(r'\s*model\s*:', line)]
    efforts = [line for line in lines if re.match(r'\s*effort\s*:', line)]
    model = re.fullmatch(r'model: ([A-Za-z0-9][A-Za-z0-9._-]*)', models[0]) if len(models) == 1 else None
    level = (re.fullmatch(r'effort: (low|medium|high|xhigh|max)', efforts[0])
             if len(efforts) == 1 else None)
    if model is None or (efforts and level is None):
        raise ModelLaunchError('config-invalid',
                               'trusted role frontmatter model/effort is missing, malformed or ambiguous')
    return ('matching' if model[1] == native_model and level is not None and level[1] == effort
            else 'generated')


def trusted_role_alignment(root, transport_role, native_model, effort):
    """Actual trusted role definition handling; an absent definition can only be generated."""
    relative = role_definition_path(transport_role)
    parts = pathlib.PurePosixPath(relative).parts
    model_require(not any(root.joinpath(*parts[:index]).is_symlink()
                          for index in range(1, len(parts) + 1)),
                  'config-invalid', 'trusted role definition is symlinked')
    path = root / relative
    if not path.exists():
        return 'generated'
    try:
        text = read_regular(path, 1024 * 1024, 'trusted role definition').decode('utf-8')
    except UnicodeDecodeError:
        raise ModelLaunchError('config-invalid', 'trusted role definition is not UTF-8') from None
    role_parts = text.split('---', 2)
    model_require(len(role_parts) == 3 and not role_parts[0].strip(), 'config-invalid',
                  'trusted role frontmatter missing')
    return role_frontmatter_alignment(role_parts[1], native_model, effort)


def verify_model_launch(root, output, launch_sha256, binding, command, *, environment=None):
    """Raw-pinned model-launch.json must equal fresh controls, trusted role, exact argv and context."""
    root = pathlib.Path(root)
    environment = captured_environment(environment)
    model_require(isinstance(launch_sha256, str) and SHA256.fullmatch(launch_sha256) is not None,
                  'input-invalid', 'model launch pin must be a lowercase raw SHA-256')
    output = pathlib.Path(output)
    model_require(output.is_dir() and not output.is_symlink(), 'input-invalid',
                  'model launch output is not a directory')
    raw = read_regular(output / MODEL_LAUNCH_RECORD, MAX_LAUNCH_RECORD, MODEL_LAUNCH_RECORD)
    model_require(hashlib.sha256(raw).hexdigest() == launch_sha256, 'input-invalid',
                  'model-launch.json differs from its raw pin')
    record = strict_document(raw, MODEL_LAUNCH_RECORD)
    model_require(set(record) == LAUNCH_FIELDS, 'input-invalid',
                  'model-launch.json fields are not the closed launch binding')
    checked_model_binding(binding)
    alignment = trusted_role_alignment(root, binding['transport_role'], binding['native_model'],
                                       binding['effort'])
    model_require(raw == canonical_bytes(model_launch_document(binding, command, alignment)),
                  'config-conflict', 'model-launch.json differs from the binding, trusted role, '
                  'exact argv or captured native context')
    # The caller binding is only a candidate until fresh controls reproduce it exactly.
    fresh_model_binding(root, binding, environment)
    return record


def selected_model_context(root, data, role_name, role, binding, environment):
    """Selected route: generated agent, fresh controls and the same captured child context agree."""
    checked_model_binding(binding)
    model_require(binding['transport_role'] == role_name == data['role'], 'scope-mismatch',
                  'model binding role differs from the launched agent')
    model_require(role.get('model') == binding['native_model'] and role.get('effort') == binding['effort'],
                  'native-precedence-conflict', 'generated agent model/effort differs from the selection')
    model_require(environment is not None, 'input-invalid',
                  'selected launch requires the captured environment snapshot')
    environment = captured_environment(environment)
    model_require(native_overrides(environment) == binding['native_overrides'],
                  'native-precedence-conflict', 'captured native overrides differ from the validated binding')
    fresh = model_launch_binding(root, data, binding['controls'].get('path'), binding['controls'].get('sha256'),
                                 environment=environment)
    model_require(canonical_bytes(fresh) == canonical_bytes(binding), 'config-conflict',
                  'model binding differs from fresh controls validation')


def claude_argv(root, data, executable, session, role_name, role, settings_path, *,
                fixed_inputs=None, model_binding=None):
    """One pure argv renderer; selected role JSON is deterministic, legacy bytes unchanged."""
    selected_model = role['model']
    if model_binding is not None:
        # Stable selected serialization preserves established native role field order.
        fields = ('description', 'prompt', 'model', 'tools', 'disallowedTools', 'effort')
        role = {key: role[key] for key in (*fields, *sorted(set(role) - set(fields))) if key in role}
    command = ['rtk', 'proxy', executable, '-p', '--session-id', session,
               '--model', selected_model, '--permission-mode', 'dontAsk',
               '--tools', 'Read,Bash', '--disallowedTools',
               'Grep,Glob,Write,Edit,NotebookEdit',
               '--settings', str(settings_path), '--agents',
               json.dumps({role_name: role}), '--agent', role_name, '--output-format', 'json']
    if not fixed_inputs:
        command += ['--plugin-dir', str(root / 'plugins/sdd-review-loop')]
    if data['stage'] in JSON_REVIEW_STAGES:
        command += ['--json-schema', json.dumps(review_output_schema(data['stage'], role_name))]
    if model_binding is not None:
        # Only additions: the resolved effort flag and no user/project/local settings sources.
        index = command.index('--permission-mode')
        command[index:index] = ['--effort', model_binding['effort']]
        index = command.index('--agents')
        command[index:index] = ['--setting-sources', '']
    return command


def claude_command(root, session, role_name, role, permissions, settings_path,
                   invocation, receipt, policy_path, *, fixed_inputs=None,
                   model_binding=None, environment=None):
    """One argv builder for the unreserved diagnostic and formal transport.

    Without model_binding the legacy Sonnet argv is unchanged. A selected binding is checked
    against fresh controls and the same captured child environment the wrapper will use.
    """
    identity(session)
    data, _ = manifest(root, invocation)
    selected_model = role.get('model')
    require((model_binding is not None or selected_model == 'sonnet') and
            role.get('tools') == agent_tools(data['stage']) and
            role.get('disallowedTools') == ['Grep', 'Glob', 'Write', 'Edit', 'NotebookEdit'] and
            isinstance(selected_model, str), 'unsupported role permission profile')
    require(data['host_session_id'] == session, 'session differs from invocation')
    if model_binding is None:
        require(environment is None, 'a captured launch environment requires selected model controls')
    else:
        selected_model_context(root, data, role_name, role, model_binding, environment)
    policy_bytes, expected_settings = launch_policy(root, invocation, receipt, policy_path,
                                                     fixed_inputs=fixed_inputs)
    require(policy_path.read_bytes() == policy_bytes and load(settings_path) == expected_settings,
            'session guard settings or policy mismatch')
    relative = invocation.relative_to(root).as_posix()
    require(permissions == (['Read'] if fixed_inputs else
            receipt_control(data, receipt.read_text(), relative, root=root)['exact_permission_rules']),
            'permission rules mismatch')
    if fixed_inputs:
        require(fixed_input_binding(root, data, fixed_inputs['record'], fixed_inputs['snapshot']) == fixed_inputs,
                'fixed input binding changed')
    else:
        admitted_raw_hashes(root, data)
    require((root / 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs').is_file(),
            'session guard missing')
    executable = shutil.which('claude')
    if executable is None:
        raise ValueError('Claude executable missing')
    command = claude_argv(root, data, executable, session, role_name, role, settings_path,
                         fixed_inputs=fixed_inputs, model_binding=model_binding)
    help_result = subprocess.run(['rtk', 'proxy', executable, '--help'],
                                 capture_output=True, text=True, cwd=root, timeout=30)
    require(help_result.returncode == 0, 'Claude help failed')
    declarations = '\n'.join(line.split('  ', 1)[0] for line in
                             (line.strip() for line in help_result.stdout.splitlines())
                             if line.startswith('-'))

    def declared(flag):
        return re.search(r'(?<![\w-])' + re.escape(flag) + r'(?=[\s,=<\[]|$)', declarations) is not None
    if model_binding is not None:
        model_require(declared('--effort'), 'effort-unavailable',
                      'installed Claude help does not declare --effort')
    for flag in ('-p', '--session-id', '--model', '--permission-mode', '--tools',
                 '--disallowedTools', '--settings',
                 *(['--plugin-dir'] if not fixed_inputs else []),
                 '--agents', '--agent', '--output-format',
                 *(['--json-schema'] if data['stage'] in JSON_REVIEW_STAGES else []),
                 *(['--setting-sources'] if model_binding is not None else [])):
        require(declared(flag), 'unsupported CLI argument: ' + flag)
    if model_binding is not None:
        selected_argv(command, model_binding)
    return command


def agent_tools(stage):
    """StructuredOutput is output-only for JSON review stages."""
    return ['Read', 'Bash', 'StructuredOutput'] if stage in JSON_REVIEW_STAGES else ['Read', 'Bash']


def native_messages(rows, session):
    """Select executed conversation events, never API-request replay payloads."""
    selected, used, pending = [], set(), set()
    for row in rows:
        require(isinstance(row, dict) and
                (row.get('sessionId') == session or
                 (row.get('type') == 'file-history-snapshot' and 'sessionId' not in row)),
                'native transcript contains a different session')
        kind = row.get('type')
        if kind not in ('assistant', 'user'):
            continue
        message = row.get('message')
        require(isinstance(message, dict), 'native conversation message is malformed')
        content = message.get('content')
        for block in content if isinstance(content, list) else []:
            if not isinstance(block, dict):
                continue
            if block.get('type') == 'tool_use':
                require(kind == 'assistant', 'native tool use outside assistant turn')
                tool_id = block.get('id')
                require(isinstance(tool_id, str) and bool(tool_id) and tool_id not in used,
                        'native tool-use identity missing or repeated')
                used.add(tool_id)
                pending.add(tool_id)
            elif block.get('type') == 'tool_result':
                require(kind == 'user', 'native tool result outside user turn')
                tool_id = block.get('tool_use_id')
                require(isinstance(tool_id, str) and tool_id in pending,
                        'native tool result lacks matching pending use')
                pending.remove(tool_id)
        selected.append(row)
    return selected


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


def checked_invocation(data):
    """Existing protected document checks, shared without ledger or reservation I/O."""
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
    if stage == 'domain':
        require(data.get('feature') == DOMAIN_FEATURE,
                'domain invocation feature is not the domain-model namespace')
    session = data.get('host_session_id')
    identity(session)
    require(data.get('run_id') == session,
            'non-TTY adapter must alias run_id to the one proposed session UUID')
    ledger_rel = data.get('identity_ledger_path')
    require(ledger_rel == 'reports/review-context/identity-ledger.json',
            'unexpected ledger path')
    return data


def manifest(root, path):
    data = load(path)
    checked_invocation(data)
    ledger_rel = data['identity_ledger_path']
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


def inputs_bound(data):
    return data['stage'] in ('spec', 'impl', 'domain') or any(
        entry.get('path') == 'specs/' + data['feature'] + '/concept-test.json'
        for entry in data.get('allowed_input_manifest', []))


def compact_receipt_control(root, data, receipt_text, invocation_path, original,
                            invocation_hash, boundary_hash, raw_hash, source_hash):
    """Existing compact permission rendering; hashes come from admitted captured counterparts."""
    source = root / 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'
    entries = data['allowed_input_manifest']
    inputs_text, inputs_hash = original['inputs_text'], original['inputs_sha256']
    record_text, digest = original['record_text'], original['record_sha256']
    bootstrap = ('import hashlib,pathlib,sys; p=pathlib.Path(sys.argv[1]); b=p.read_bytes(); '
                 'valid=not any(q.is_symlink() for q in (p,*p.parents)) and hashlib.sha256(b).hexdigest()==sys.argv[2]; '
                 'valid or sys.exit("verifier hash mismatch"); '
                 'n={"__name__":"pinned_review_verifier","__file__":str(p)}; '
                 'exec(compile(b,str(p),"exec"),n); '
                 'print(n["compact_verify"](pathlib.Path.cwd(),*sys.argv[3:]))')
    command = 'rtk proxy python3 -B -c ' + shlex.quote(bootstrap) + ' ' + ' '.join(
        shlex.quote(value) for value in (str(source), source_hash, invocation_path,
            invocation_hash, boundary_hash, raw_hash, receipt_text.rstrip('\n')))
    control: dict[str, Any] = {'inputs_text': inputs_text, 'inputs_sha256': inputs_hash,
               'record_text': record_text, 'record_sha256': digest,
               'compact_command': command, 'hash_commands': [command],
               'exact_permission_rules': ['Bash(' + command + ')']}
    control['compact_output'] = compact_result(control, invocation_hash, boundary_hash, raw_hash, len(entries))
    if data['stage'] == 'quality':
        control['scratch_declaration_sha256'] = original['scratch_declaration_sha256']
    else:
        control['exact_permission_rules'].append('Bash(rtk proxy test -d domain)')
    return control


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
        if data['stage'] in ('impl', 'task', 'domain'):
            require(not re.fullmatch(r'reviewer-[ab]\.json', entry['path'].rsplit('/', 1)[-1]),
                    'raw reviewer output is not an impl input')
    inputs_text = '\n'.join(entry['path'] + '\t' + entry['sha256'] for entry in entries)
    inputs_hash = hashlib.sha256(inputs_text.encode('utf-8')).hexdigest()
    fields = [str(data['sequence']), data['stage'], data['role'], data['run_id'],
              data['host_session_id'], previous]
    if any(not isinstance(v, str) or any(c in v for c in '|\r\n\x00') for v in fields):
        raise ValueError('invalid record field')
    record_text = '|'.join(fields)
    if data['stage'] == 'quality':
        scratch_binding = hashlib.sha256((data['feature'] + '\n' +
                                          data['scratch_root']).encode('utf-8')).hexdigest()
        record_text += '|scratch-declaration-v1|' + scratch_binding
    if inputs_bound(data):
        record_text += '|allowed-inputs-v1|' + inputs_hash
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
        original = {'inputs_text': inputs_text, 'inputs_sha256': inputs_hash,
                    'record_text': record_text, 'record_sha256': digest}
        if data['stage'] == 'quality':
            original['scratch_declaration_sha256'] = scratch_binding
        return compact_receipt_control(root, data, receipt_text, invocation_path, original,
                                       invocation_hash, boundary_hash, raw_hash, sha(source))
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
    control: dict[str, Any] = {'inputs_text': inputs_text, 'inputs_sha256': inputs_hash,
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
    enforced = data['stage'] in ('impl', 'task', 'quality', 'domain') or strict
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
        + ('|scratch-declaration-v1| and SHA-256 of feature LF scratch_root (no terminal newline), then '
           if data['stage'] == 'quality' else '')
        + ('|allowed-inputs-v1| and that input digest. '
           if inputs_bound(data) else 'nothing else. ')
        + 'Hash its exact UTF-8 bytes. '
        'Use the two literal no-newline hash commands only after checking their text against this '
        'independent reconstruction. Caller-provided digests alone are not reviewer proof. '
        + order_note
        + retry_note
        + 'Require equality to the quoted receipt and sequence=tip+1, previous link equality and '
        'identity_unique=yes before reviewing substantive inputs. If any operation cannot be '
        'performed, stop without a verdict. Never inspect the ledger or reserve again.\n')


def fixed_input_binding(root, data, record_path=None, snapshot_path=None):
    """Verify selected Git inputs; the record never grants review authority."""
    require(bool(record_path) == bool(snapshot_path), 'fixed input record and snapshot must be paired')
    if record_path is None:
        return None
    record_path, snapshot_path = pathlib.Path(record_path), pathlib.Path(snapshot_path)
    require(record_path.is_file() and not record_path.is_symlink(), 'invalid fixed input record')
    inventory = load(record_path)
    spec = importlib.util.spec_from_file_location(
        'fixed_review_inputs', pathlib.Path(__file__).with_name('fixed-review-inputs.py'))
    if spec is None or spec.loader is None:
        raise ValueError('fixed input helper is not loadable')
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    helper.validate_inventory(inventory)
    selected = [entry['path'] for entry in inventory['inputs']]
    helper.verify_revision(root, inventory['commit'], selected, snapshot_path, inventory)
    admitted_hashes = {entry['path']: entry['sha256'] for entry in data['allowed_input_manifest']}
    require(len(admitted_hashes) == len(data['allowed_input_manifest']),
            'duplicate manifest input path')
    admitted = set(admitted_hashes)
    # Generated review evidence stays live and hash-bound by the existing manifest.
    required = {name for name in admitted if not name.startswith('reports/')
                and not (name.startswith('specs/') and '/verification/' in name)}
    require(set(selected) == required, 'fixed input selection differs from required source inputs')
    helper.verify_head_selection(root, inventory)
    raw_hashes = admitted_raw_hashes(root, data, {
        'record': str(record_path), 'snapshot': str(snapshot_path), 'inventory': inventory})
    for entry in inventory['inputs']:
        require(raw_hashes[entry['path']] == entry['sha256'],
                'fixed input differs from manifest hash: ' + entry['path'])
    approvals = [name for name in admitted_hashes
                 if name.startswith('reports/review-context/fixed-approvals/')]
    states = [name for name in admitted_hashes
              if name.startswith('reports/review-context/fixed-states/')]
    require(len(approvals) <= 1, 'multiple fixed approvals admitted')
    require(len(states) <= 1, 'multiple fixed states admitted')
    require('fixed_approval_path' not in data, 'fixed approval must use the input manifest')
    references = {}
    if approvals or states:
        auth_spec = importlib.util.spec_from_file_location(
            'fixed_approval_context', root / 'plugins/sdd-quality-loop/scripts/validate-approval-sidecar.py')
        if auth_spec is None or auth_spec.loader is None:
            raise ValueError('fixed approval helper is not loadable')
        auth = importlib.util.module_from_spec(auth_spec)
        auth_spec.loader.exec_module(auth)
        trust = dict(key=auth._resolve_key_or_raise(),
                     registry_ids=auth._validate_registry(root / 'sdd/approver-registry.yaml'))
    if approvals:
        approval_path = approvals[0]
        approval_file = safe_compact_path(root, approval_path)
        require(sha(approval_file) == admitted_hashes[approval_path],
                'fixed approval input changed')
        helper.verify_approval(load(approval_file), inventory,
            feature=data['feature'], stage=data['stage'], task_id=data.get('task_id'),
            **trust)
        references['approval_reference'] = {'path': approval_path, 'sha256': sha(approval_file)}
    if states:
        state_file = safe_compact_path(root, states[0])
        require(sha(state_file) == admitted_hashes[states[0]], 'fixed state input changed')
        state_spec = importlib.util.spec_from_file_location(
            'fixed_review_state', pathlib.Path(__file__).with_name('fixed-review-state.py'))
        if state_spec is None or state_spec.loader is None:
            raise ValueError('fixed state helper is not loadable')
        state_helper = importlib.util.module_from_spec(state_spec)
        state_spec.loader.exec_module(state_helper)
        document = load(state_file)
        state_helper.verify(document, root, inventory, feature=data['feature'],
                            stage=data['stage'], task_id=data.get('task_id'), **trust)
        if approvals:
            require(document['approval'] == load(approval_file), 'fixed state approval differs')
        references['progress_reference'] = {'path': states[0], 'sha256': sha(state_file)}
    return {'record': str(record_path.resolve()), 'snapshot': str(snapshot_path.resolve()),
            'inventory': inventory, 'state_reference': helper.state_reference(root, inventory),
            **references}


def record_fixed_execution(output, invocation, data, fixed_inputs):
    """Bind detached execution evidence; this record never grants approval."""
    if fixed_inputs is None:
        return None
    snapshot = pathlib.Path(fixed_inputs['snapshot']).resolve()
    destination = output.resolve()
    require(destination != snapshot and snapshot not in destination.parents,
            'execution evidence must be outside fixed inputs')
    document = {
        'schema': 'sdd-fixed-review-execution/v1',
        'invocation_sha256': sha(invocation),
        'stage': data['stage'], 'role': data['role'], 'feature': data['feature'],
        'inputs': fixed_inputs['inventory'],
        'state_reference': fixed_inputs['state_reference'],
    }
    for name in ('approval_reference', 'progress_reference'):
        if name in fixed_inputs:
            document[name] = fixed_inputs[name]
    path = output / 'fixed-execution.json'
    write_launch_text(path, json.dumps(document, sort_keys=True) + '\n', exclusive=True)
    return sha(path)


def record_fixed_delivery(output, execution_digest):
    """Bind delivery bytes to the execution, without interpreting a verdict."""
    if execution_digest is None:
        return
    for name in ('fixed-execution.json', 'delivery.json'):
        path = output / name
        require(not path.is_symlink(), 'fixed delivery artifact is symlinked')
        require(path.stat().st_mode & 0o170000 == 0o100000,
                'fixed delivery artifact is not a regular file')
    require(sha(output / 'fixed-execution.json') == execution_digest,
            'fixed execution binding changed during review')
    document = {
        'schema': 'sdd-fixed-review-delivery/v1',
        'execution_sha256': execution_digest,
        'delivery_sha256': sha(output / 'delivery.json'),
    }
    write_launch_text(output / 'fixed-delivery.json',
                      json.dumps(document, sort_keys=True) + '\n', exclusive=True)


def verify_fixed_delivery(output, execution_digest, invocation):
    """Use the caller's execution binding, not a digest supplied by the record."""
    if execution_digest is None:
        return
    for name in ('fixed-execution.json', 'fixed-delivery.json', 'delivery.json'):
        path = output / name
        require(path.is_file() and not path.is_symlink(),
                'fixed delivery artifact missing or symlinked')
    execution_path = output / 'fixed-execution.json'
    require(sha(execution_path) == execution_digest, 'fixed execution binding changed')
    execution = load(execution_path)
    require(execution.get('schema') == 'sdd-fixed-review-execution/v1' and
            execution.get('invocation_sha256') == sha(invocation),
            'fixed invocation binding changed')
    require(load(output / 'fixed-delivery.json') == {
        'schema': 'sdd-fixed-review-delivery/v1',
        'execution_sha256': execution_digest,
        'delivery_sha256': sha(output / 'delivery.json'),
    }, 'fixed delivery binding changed')


def review_read_paths(root, invocation, data, fixed_inputs=None):
    selected = {entry['path'] for entry in fixed_inputs['inventory']['inputs']} if fixed_inputs else set()
    paths = [invocation, root / BOUNDARY_PATH]
    paths.extend((pathlib.Path(fixed_inputs['snapshot']) if entry['path'] in selected else root)
                 / entry['path'] for entry in data['allowed_input_manifest'])
    return paths


def guard_policy_documents(root, data, control, paths, policy_path, *, fixed_inputs=None):
    """Existing guard/settings rendering over already validated or captured path identities."""
    bash = [] if fixed_inputs else list(control['hash_commands'])
    if not fixed_inputs and data['stage'] != 'quality':
        bash.append('rtk proxy test -d domain')
    policy = {'schema': 'impl-nontty-pretool/v1',
              'read_paths': [str(path) for path in paths],
              'bash_commands': bash}
    if data['stage'] in JSON_REVIEW_STAGES:
        policy['output_tool'] = 'StructuredOutput'
    guard = root / 'plugins/sdd-review-loop/scripts/nontty-impl-pretool-guard.mjs'
    policy_bytes = json.dumps(policy, sort_keys=True, separators=(',', ':')).encode('utf-8')
    policy_sha256 = hashlib.sha256(policy_bytes).hexdigest()
    command = ('rtk proxy node ' + shlex.quote(str(guard)) + ' ' +
               shlex.quote(str(policy_path)) + ' ' + policy_sha256 + ' || exit 2')
    settings = {'permissions': {'allow': ['Read'] if fixed_inputs else control['exact_permission_rules']},
                'hooks': {'PreToolUse': [
        {'matcher': '*', 'hooks': [{'type': 'command', 'command': command}]}]}}
    return policy_bytes, settings


def launch_policy(root, invocation, receipt, policy_path, *, fixed_inputs=None):
    data, _ = manifest(root, invocation)
    invocation_relative = invocation.relative_to(root).as_posix()
    control = receipt_control(data, receipt.read_text(), invocation_relative,
                              root=None if fixed_inputs else root)
    paths = review_read_paths(root, invocation, data, fixed_inputs)
    for path in paths:
        path_root = root if path.is_relative_to(root) else pathlib.Path(fixed_inputs['snapshot'])
        relative = path.relative_to(path_root)
        require(path.is_file() and not any(
            (path_root / pathlib.Path(*relative.parts[:index])).is_symlink()
            for index in range(1, len(relative.parts) + 1)),
                'impl admitted path is missing or symlinked')
    return guard_policy_documents(root, data, control, [path.resolve() for path in paths],
                                  policy_path, fixed_inputs=fixed_inputs)


def expected_prompt(root, invocation, receipt, *, strict=False, conditional_state=None,
                    fixed_inputs=None):
    data, _ = manifest(root, invocation)
    enforced = data['stage'] in ('impl', 'task', 'quality', 'domain') or strict
    receipt_text = receipt.read_bytes().decode('utf-8')
    require(re.fullmatch(r'REVIEW_CONTEXT_OK [0-9a-f]{64} sequence=[1-9][0-9]* '
                         r'previous_record_sha256=(?:-|[0-9a-f]{64}) pre_append_tip_sequence=(?:-|[0-9]+) '
                         r'identity_unique=yes\n?',
                         receipt_text) is not None, 'invalid reservation receipt text')
    relative = invocation.resolve().relative_to(root.resolve()).as_posix()
    binding = json.dumps({'role': data['role'], 'invocation': relative,
                          'run_id': data['run_id'], 'host_session_id': data['host_session_id'],
                          'invocation_sha256': sha(invocation),
                          'receipt': receipt_text.rstrip('\n')},
                         ensure_ascii=True, sort_keys=True)
    review_name = {'spec': 'spec', 'impl': 'implementation-policy', 'task': 'task-decomposition',
                   'quality': 'quality-gate', 'domain': 'domain-model'}[data['stage']]
    task_hash_note = (
        'Task transport raw SHA-256 observations: ' + json.dumps(admitted_raw_hashes(root, data), sort_keys=True)
        + '\nCompare file hash commands with these raw observations. The tasks.md manifest digest '
        'may instead be normalized by the canonical task precheck; never replace that manifest '
        'digest in the receipt or review output. Canonical verification remains mandatory.\n'
        if data['stage'] == 'task' and not fixed_inputs else '')
    conditional_note = (
        'Pre-reservation conditional-input resolution, rechecked immediately before reservation '
        '(launch-control observation, not a review verdict): '
        + json.dumps(conditional_state, ensure_ascii=True, sort_keys=True) + '\n'
        + 'Use the observed presence and domain/design-system eligibility for the role checks and '
        'state the applicable SKIP reason. Do not run directory/presence shell probes; this session '
        + ('permits no Bash commands. ' if fixed_inputs else
           'permits only the exact listed Bash commands. ')
        + 'Inspect admitted substantive inputs independently.\n'
        if strict and conditional_state is not None else '')
    if fixed_inputs:
        return ('SDD independent ' + review_name + ' review; manifest-only, read-only.\n'
                + binding + '\n'
                + 'Input identity has been verified by the launcher against the fixed Git revision. '
                'Do not run hash commands or any Bash command. Do not reserve again.\n'
                + 'Read the following exact absolute paths; retain original relative path identities '
                'in your output:\n'
                + json.dumps([str(p.resolve()) for p in
                              review_read_paths(root, invocation, data, fixed_inputs)]) + '\n'
                + 'Fixed input binding: ' + json.dumps(fixed_inputs['inventory'], sort_keys=True) + '\n'
                + conditional_note
                + 'Inspect every required input independently. Do not read peer outputs or modify '
                'files. A prior verdict or identity verification does not prove review coverage. '
                'Report only checks actually inspected; never claim tests were rerun.\n'
                + ('Return the evaluator plaintext contract: RUN_ID and HOST_SESSION_ID from the '
                   'invocation, ALLOWED_INPUT_MANIFEST with invocation path and SHA-256, '
                   'VERDICT: PASS or NEEDS_WORK, FINDINGS: and CHECKED:. Missing coverage is '
                   'NEEDS_WORK. List tests not rerun.\n' if data['stage'] == 'quality' else
                   'Return only the complete canonical role JSON with invocation run/session '
                   'identities and all required checks.\n')).encode('utf-8')
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


def read_coverage(target, content):
    if isinstance(content, list):
        require(all(isinstance(item, dict) and item.get('type') == 'text' and
                    isinstance(item.get('text'), str) for item in content),
                'fixed Read result is not text')
        content = '\n'.join(item['text'] for item in content)
    require(isinstance(content, str), 'fixed Read result is not text')
    expected = target.read_text(encoding='utf-8')
    lines = expected.splitlines()
    if content == expected:
        return set(range(len(lines))), len(lines)
    covered = set()
    for line in content.splitlines():
        match = re.fullmatch(r'\s*([1-9][0-9]*)(?:\t|→)(.*)', line)
        if match:
            index = int(match[1]) - 1
            require(index < len(lines) and match[2] == lines[index],
                    'fixed Read content differs from admitted input')
            covered.add(index)
    require(bool(covered), 'fixed Read result contains no admitted content')
    return covered, len(lines)


def native_delivery(root, invocation, transcript, prompt, wrapper, receipt, *, strict=False,
                    conditional_state=None, fixed_inputs=None):
    data, ledger = manifest(root, invocation)
    enforced = data['stage'] in ('impl', 'task', 'quality', 'domain') or strict
    require(prompt.read_bytes() == expected_prompt(root, invocation, receipt, strict=strict,
                                                   conditional_state=conditional_state,
                                                   fixed_inputs=fixed_inputs),
            'prompt differs from complete canonical launch template')
    session = data['host_session_id']
    require(sum(record.get('run_id') == session and record.get('host_session_id') == session
                for record in ledger['records']) == 1,
            'reserved identity absent or repeated')
    meta_turn_seen = False
    if enforced:
        control = receipt_control(data, receipt.read_text(), invocation.relative_to(root).as_posix(),
                                  root=None if fixed_inputs else root)
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
        if inputs_bound(data):
            record_fields.append(('allowed_inputs_sha256', control['inputs_sha256']))
        require(all(record.get(field) == value for field, value in record_fields),
            'reserved ledger record differs from invocation or receipt')
    require(transcript.is_file() and transcript.name == session + '.jsonl',
            'native transcript missing or wrong session')
    result = load(wrapper)
    require(result.get('session_id') == session and result.get('is_error') is False and
            result.get('type') == 'result', 'host result did not accept proposed session')
    rows = [json.loads(line) for line in transcript.read_text().splitlines() if line.strip()]
    messages = native_messages(rows, session)
    if enforced:
        allowed_reads = {p.resolve() for p in review_read_paths(root, invocation, data, fixed_inputs)}
        allowed_bash = set() if fixed_inputs else set(control['hash_commands'])
        batch_command = None if fixed_inputs else control['compact_command']
        if data['stage'] != 'quality' and not fixed_inputs:
            allowed_bash.add('rtk proxy test -d domain')
        required_hashes: dict[str, str | None] = {}
        if not fixed_inputs:
            if not isinstance(batch_command, str) or not batch_command:
                raise ValueError('missing compact verification command')
            required_hashes[batch_command] = None
        required_order = list(required_hashes)
        file_hash_order = [] if fixed_inputs else [batch_command]
        proven: set[str] = set()
        pending: dict[str, Any] = {}
        pending_reads: dict[str, pathlib.Path] = {}
        completed_reads: set[pathlib.Path] = set()
        covered_reads: dict[pathlib.Path, set[int]] = {}
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
                        target = pending_reads.pop(tool_id)
                        if fixed_inputs:
                            covered, total = read_coverage(target, result_text)
                            covered_reads.setdefault(target, set()).update(covered)
                            if len(covered_reads[target]) == total:
                                completed_reads.add(target)
                        else:
                            completed_reads.add(target)
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
                    pending_reads[block['id']] = target
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
                    require(not fixed_inputs or allowed_reads <= completed_reads,
                            'fixed review StructuredOutput preceded required Read results')
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
        require(not fixed_inputs or allowed_reads <= completed_reads,
                'fixed review transcript lacks required Read results')
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
               conditional_state=None, fixed_inputs=None):
    data, result, messages = native_delivery(root, invocation, transcript, prompt, wrapper,
                                             receipt, strict=strict,
                                             conditional_state=conditional_state,
                                             fixed_inputs=fixed_inputs)
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
            admitted = {p.resolve() for p in review_read_paths(root, invocation, data, fixed_inputs)[2:]}
            observed_reads = [block.get('input', {}).get('file_path')
                              for item in messages if item.get('type') == 'assistant'
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


# Retrospective records: consistency only, never a replacement for prelaunch eligibility.
EXECUTION_FIELDS = frozenset(('schema', 'transport', 'stage', 'role', 'run_id', 'session_id', 'attempt',
    'invocation', 'dependencies', 'role_definition', 'policy', 'settings', 'receipt', 'fixed_inputs',
    'policy_environment', 'native_overrides', 'executable'))
DELIVERY_BINDING_FIELDS = frozenset(('schema', 'launch_sha256', 'transport', 'selection', 'events', 'delivery',
    'execution_context', 'run_id', 'session_id', 'attempt', 'selection_sha256'))
MAIN_MODEL_ROLES = frozenset(('implementer', 'investigator', 'evaluator', 'diagnosis', 'self-improvement'))


class EvidenceCapture:
    """Read only explicit canonical references, with one aggregate byte budget and no reopening."""
    def __init__(self, root, *, runtime_root=None):
        self.root = pathlib.Path(root).resolve()
        self.runtime_root = self.root if runtime_root is None else pathlib.Path(runtime_root).resolve()
        self.bytes: dict[str, bytes] = {}
        self.pins: dict[str, str] = {}
        # One physical root retains the original cache, conflicting-pin checks and byte accounting.
        self.runtime_bytes: dict[str, bytes] = self.bytes if self.runtime_root == self.root else {}
        self.runtime_pins: dict[str, str] = self.pins if self.runtime_root == self.root else {}
        self.remaining = MAX_LAUNCH_RECORD

    def read(self, reference):
        return self._read(reference, self.root, self.bytes, self.pins)

    def read_runtime(self, reference):
        return self._read(reference, self.runtime_root, self.runtime_bytes, self.runtime_pins)

    def _read(self, reference, root, raw_cache, pin_cache):
        model_require(isinstance(reference, dict) and set(reference) == {'path', 'sha256'},
                      'input-invalid', 'evidence reference is not closed')
        path = control_path_text(reference['path'])
        digest = reference['sha256']
        model_require(isinstance(digest, str) and SHA256.fullmatch(digest) is not None,
                      'input-invalid', 'evidence raw pin is invalid')
        if path in raw_cache:
            model_require(pin_cache[path] == digest, 'input-invalid', 'conflicting evidence pins')
            return raw_cache[path]
        raw = read_regular(root / path, self.remaining, 'model evidence')
        model_require(hashlib.sha256(raw).hexdigest() == digest, 'input-invalid', 'model evidence raw pin mismatch')
        self.remaining -= len(raw)
        raw_cache[path], pin_cache[path] = raw, digest
        return raw

    def document(self, reference):
        return strict_document(self.read(reference), 'model evidence')


def local_reference(root, path):
    path = pathlib.Path(path)
    relative = path.relative_to(root).as_posix()
    control_path_text(relative)
    return {'path': relative, 'sha256': hashlib.sha256(read_regular(path, MAX_LAUNCH_RECORD,
                                                                   'execution artifact')).hexdigest()}


def write_model_record(output, name, value, *, directory_fd=None):
    raw = canonical_bytes(value)
    write_model_bytes(output, name, raw, directory_fd=directory_fd)
    return hashlib.sha256(raw).hexdigest()


def write_model_bytes(output, name, raw, *, directory_fd=None):
    model_require(isinstance(name, str) and pathlib.PurePosixPath(name).name == name and
                  name not in ('', '.', '..') and '/' not in name and '\\' not in name,
                  'input-invalid', 'unsafe model output name')
    with model_output_directory(output, directory_fd) as held:
        output_directory_identity(output, held)
        descriptor = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW |
                             os.O_NONBLOCK | getattr(os, 'O_CLOEXEC', 0), 0o600, dir_fd=held)
        with os.fdopen(descriptor, 'wb') as stream:
            stream.write(raw)


def policy_environment(environment, root):
    # Only allowlisted nonsecret model configuration values; never persist the child environment.
    policy = strict_document(read_regular(root / 'contracts/model-policy.v1.json', MAX_LAUNCH_RECORD,
                                          'trusted role policy'), 'trusted role policy')
    names = {'SDD_MODEL_POLICY', *(role['model_env'] for role in policy['roles'].values())}
    return {name: environment[name] for name in sorted(names) if name in environment}


def record_model_execution(root, output, data, invocation, role_path, policy_path, settings_path, receipt,
                           binding, command, environment, fixed_inputs=None):
    """Capture the actual launch context, while existing admission still owns execution authority."""
    with model_output_directory(output) as directory_fd:
        dependencies_path = output / 'dependencies.json'
        dependencies = strict_document(read_regular(dependencies_path, MAX_LAUNCH_RECORD, 'dependencies'), 'dependencies')
        executable = command[2]
        resolved = str(pathlib.Path(executable).resolve(strict=True))
        model_require(resolved in dependencies, 'input-invalid', 'native executable is not dependency-pinned')
        fixed = None
        if fixed_inputs is not None:
            inventory_name = 'model-fixed-inputs.json'
            # The existing binding was validated before dispatch. Capture its original bytes verbatim.
            raw = read_regular(pathlib.Path(fixed_inputs['record']), MAX_LAUNCH_RECORD, 'fixed inventory')
            model_require(strict_document(raw, 'fixed inventory') == fixed_inputs['inventory'],
                          'config-conflict', 'fixed inventory changed before execution context capture')
            write_model_bytes(output, inventory_name, raw, directory_fd=directory_fd)
            fixed = {'inventory': local_reference(root, output / inventory_name),
                     'execution': local_reference(root, output / 'fixed-execution.json'),
                     'snapshot': fixed_inputs['snapshot']}
        context = {'schema': 'model-execution-context/v1', 'transport': MODEL_TRANSPORT,
                   'stage': data['stage'], 'role': data['role'], 'run_id': binding['run_id'],
                   'session_id': binding['session_id'], 'attempt': binding['attempt'],
                   'invocation': local_reference(root, invocation),
                   'dependencies': local_reference(root, dependencies_path),
                   'role_definition': local_reference(root, role_path),
                   'policy': local_reference(root, policy_path), 'settings': local_reference(root, settings_path),
                   'receipt': local_reference(root, receipt), 'fixed_inputs': fixed,
                   'policy_environment': policy_environment(environment, root),
                   'native_overrides': native_overrides(environment),
                   'executable': {'path': executable, 'resolved_path': resolved, 'sha256': dependencies[resolved]}}
        return write_model_record(output, 'model-execution-context.json', context, directory_fd=directory_fd)

def captured_model_helper(capture, trusted, *, runtime=False):
    model_require(isinstance(trusted, list) and
                  [ref.get('path') for ref in trusted if isinstance(ref, dict)] == list(TRUSTED_MODEL_RUNTIME),
                  'input-invalid', 'trusted model runtime inventory differs')
    reader = capture.read_runtime if runtime else capture.read
    raw_cache = capture.runtime_bytes if runtime else capture.bytes
    root = capture.runtime_root if runtime else capture.root
    for reference in trusted:
        reader(reference)
    name = 'captured_delivery_model_policy'
    spec = importlib.util.spec_from_loader(name, loader=None)
    if spec is None:
        raise ValueError('captured model helper is not loadable')
    module = importlib.util.module_from_spec(spec)
    module.__file__ = str(root / MODEL_POLICY_HELPER)
    exec(compile(raw_cache[MODEL_POLICY_HELPER], module.__file__, 'exec'), module.__dict__)
    return module


def immutable_launch_validation(capture, launch, selection, context, helper, *, role, host, runtime=False):
    controls = capture.document(launch['controls'])
    inputs, pins = helper._launch_document(controls)
    expected_pins = [{'path': path, 'sha256': pins[path]} for path in sorted(pins)]
    model_require(launch['pins'] == expected_pins, 'config-conflict', 'prelaunch control closure differs')
    for reference in expected_pins:
        capture.read(reference)
    captured = {path: capture.bytes[path] for path in pins}
    trusted = capture.runtime_bytes if runtime else capture.bytes
    if runtime:
        # Match the helper's snapshot merge exactly: controls/selection aliases are not merged.
        for path in [controls['request']['path'], controls['registry']['path'], *inputs]:
            model_require(path not in TRUSTED_MODEL_RUNTIME or captured[path] == trusted[path],
                          'config-conflict', 'captured input collides with trusted runtime snapshot')
    request, policy = helper._launch_closure(captured[controls['request']['path']], inputs, captured)
    helper._launch_authority(captured[controls['registry']['path']], policy,
        trusted['contracts/agent-model-capabilities.v2.json'], trusted['contracts/model-policy.v1.json'])
    expected_role = role
    model_require(controls['role'] == request['role'] == selection['role'] == expected_role and
                  controls['host'] == request['host'] == selection['host'] == host and
                  controls['attempt'] == context['attempt'] and controls['require_actual_id'] is False,
                  'scope-mismatch', 'captured controls differ from the actual execution context')
    original = helper.strict_json(captured[controls['selection']['path']])
    bound = helper.bind_selection(original, run_id=context['run_id'], session_id=context['session_id'],
                                   attempt=context['attempt'])
    model_require(canonical_bytes(bound) == canonical_bytes(selection), 'config-conflict',
                  'postlaunch selection differs from immutable prelaunch controls')
    observation = helper.strict_json(captured[request['observation_path']])
    helper.validate_observation_record(observation)
    model_require(selection['policy_sha256'] == hashlib.sha256(helper.canonical(policy)).hexdigest() and
                  selection['catalog_sha256'] == hashlib.sha256(helper.canonical(
                      helper.strict_json(captured[controls['registry']['path']]))).hexdigest() and
                  all(selection[key] == observation[key] for key in
                      ('host', 'scope_id', 'cli_version', 'observed_at', 'observation_sha256')) and
                  selection['risk'] == request['risk'] and selection['source_date'] == policy['source_date'] and
                  selection['budget'] == request['budget'],
                  'config-conflict', 'immutable selection differs from captured policy/catalog/observation/request')
    mapping = helper._policy_mappings(policy).get(selection['resolved']['catalog_id'], {})
    model_require(mapping.get(selection['host']) == selection['resolved']['native_id'],
                  'config-conflict', 'immutable selection differs from the trusted native mapping')
    env = context['policy_environment']
    names = {'SDD_MODEL_POLICY', *(role['model_env'] for role in policy['roles'].values())}
    model_require(isinstance(env, dict) and set(env) <= names and
                  all(isinstance(value, str) for value in env.values()), 'input-invalid',
                  'captured policy environment is not the nonsecret allowlist')
    project = (helper.strict_json(captured[request['project_config_path']]) if request['project_config_path'] else
               {'schema': 'model-role-config/v1', 'default_policy': None, 'roles': {}})
    model_require(helper._effective_configuration(request, policy, project, env) == selection['requested'],
                  'config-conflict', 'captured policy configuration differs from selection provenance')
    validation = {'schema': 'model-launch-validation/v1', 'controls': launch['controls'],
                  'pins': expected_pins, 'trusted': launch['trusted'], 'role': expected_role, 'host': host,
                  'run_id': context['run_id'], 'session_id': context['session_id'],
                  'attempt': context['attempt'], 'require_actual_id': False, 'selection': selection}
    return validation


def retrospective_binding(capture, launch, selection, context, helper):
    validation = immutable_launch_validation(capture, launch, selection, context, helper,
                                              role=MODEL_ROLES.get(context['role']), host=MODEL_HOST)
    overrides = context['native_overrides']
    model_require(isinstance(overrides, dict) and set(overrides) == set(NATIVE_OVERRIDES) and
                  all(value is None or isinstance(value, str) for value in overrides.values()),
                  'input-invalid', 'captured native overrides are not closed')
    return derived_model_binding(validation, context['role'],
                                 {key: value for key, value in overrides.items() if value is not None})


def reconstructed_command(capture, context, binding, *, feature=None):
    root = capture.root
    model_require(set(context) == EXECUTION_FIELDS and context['schema'] == 'model-execution-context/v1' and
                  context['transport'] == MODEL_TRANSPORT, 'input-invalid', 'execution context is not closed')
    for name in ('invocation', 'dependencies', 'role_definition', 'policy', 'settings', 'receipt'):
        capture.read(context[name])
    data = capture.document(context['invocation'])
    checked_invocation(data)
    model_require(context['stage'] == data['stage'] and context['role'] == data['role'] and
                  context['run_id'] == data['run_id'] and context['session_id'] == data['host_session_id'] and
                  type(context['attempt']) is int and context['attempt'] > 0 and
                  (feature is None or data.get('feature') == feature),
                  'scope-mismatch', 'execution context differs from invocation or emitter feature')
    dependencies = capture.document(context['dependencies'])
    model_require(all(isinstance(path, str) and isinstance(digest, str) and SHA256.fullmatch(digest)
                      for path, digest in dependencies.items()), 'input-invalid', 'dependency map is invalid')
    def dependency(path):
        value = dependencies.get(str(path))
        model_require(isinstance(value, str) and SHA256.fullmatch(value) is not None,
                      'input-invalid', 'required execution dependency is absent')
        return value
    role_relative = role_definition_path(data['role'])
    model_require(context['role_definition']['path'] == role_relative and
                  context['role_definition']['sha256'] == dependency(root / role_relative) and
                  context['invocation']['sha256'] == dependency(root / context['invocation']['path']),
                  'config-conflict', 'original invocation or role is not dependency-pinned')
    parts = capture.read(context['role_definition']).decode('utf-8').split('---', 2)
    model_require(len(parts) == 3 and not parts[0].strip(), 'config-invalid', 'original role frontmatter is missing')
    alignment = role_frontmatter_alignment(parts[1], binding['native_model'], binding['effort'])
    role = {'description': 'Repository-bound independent implementation reviewer', 'prompt': parts[2].strip(),
            'model': binding['native_model'], 'tools': agent_tools(data['stage']),
            'disallowedTools': ['Grep', 'Glob', 'Write', 'Edit', 'NotebookEdit'], 'effort': binding['effort']}
    control = receipt_control(data, capture.read(context['receipt']).decode('utf-8'), context['invocation']['path'])
    fixed = context['fixed_inputs']
    if fixed is not None:
        model_require(isinstance(fixed, dict) and set(fixed) == {'inventory', 'execution', 'snapshot'} and
                      isinstance(fixed['snapshot'], str) and pathlib.Path(fixed['snapshot']).is_absolute() and
                      str(pathlib.Path(fixed['snapshot'])) == fixed['snapshot'] and
                      '..' not in pathlib.Path(fixed['snapshot']).parts,
                      'input-invalid', 'fixed execution context is not closed')
        inventory, execution = capture.document(fixed['inventory']), capture.document(fixed['execution'])
        # Reuse the fixed-input record syntax validator, without Git or approval renewal.
        fixed_relative = 'plugins/sdd-review-loop/scripts/fixed-review-inputs.py'
        fixed_source = root / fixed_relative
        spec = importlib.util.spec_from_file_location('fixed_record_syntax', fixed_source)
        if spec is None or spec.loader is None:
            raise ValueError('fixed syntax helper unavailable')
        fixed_helper = importlib.util.module_from_spec(spec)
        fixed_bytes = capture.read({'path': fixed_relative, 'sha256': dependency(fixed_source)})
        exec(compile(fixed_bytes, str(fixed_source), 'exec'), fixed_helper.__dict__)
        fixed_helper.validate_inventory(inventory)
        model_require(execution.get('schema') == 'sdd-fixed-review-execution/v1' and
                      execution.get('invocation_sha256') == context['invocation']['sha256'] and
                      all(execution.get(key) == data[key] for key in ('stage', 'role', 'feature')) and
                      execution.get('inputs') == inventory and 'state_reference' in execution,
                      'config-conflict', 'fixed execution differs from invocation or inventory')
        expected_paths = {entry['path'] for entry in data['allowed_input_manifest']
                          if not entry['path'].startswith('reports/') and not
                          (entry['path'].startswith('specs/') and '/verification/' in entry['path'])}
        model_require({entry['path'] for entry in inventory['inputs']} == expected_paths,
                      'config-conflict', 'fixed inventory selection differs from invocation')
        for entry in inventory['inputs']:
            model_require(entry['sha256'] == dependency(pathlib.Path(fixed['snapshot']) / entry['path']),
                          'config-conflict', 'fixed snapshot differs from dependency evidence')
        fixed = {'snapshot': fixed['snapshot'], 'inventory': inventory}
        role['prompt'] += ('\nFixed-input route: the launcher verifies input identity. '
                           'Do not run hash-only commands or Bash. Read the exact supplied '
                           'snapshot paths; retain all substantive review checks.')
    else:
        source_relative = 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'
        raw_hashes = {entry['path']: dependency(root / entry['path']) for entry in data['allowed_input_manifest']}
        control = compact_receipt_control(root, data, capture.read(context['receipt']).decode('utf-8'),
            context['invocation']['path'], control, context['invocation']['sha256'],
            dependency(root / BOUNDARY_PATH), compact_raw_digest(data, raw_hashes), dependency(root / source_relative))
    paths = review_read_paths(root, root / context['invocation']['path'], data, fixed)
    policy, settings = guard_policy_documents(root, data, control, paths, root / context['policy']['path'],
                                               fixed_inputs=fixed)
    model_require(capture.read(context['policy']) == policy and capture.document(context['settings']) == settings,
                  'config-conflict', 'guard permissions or settings differ from captured execution context')
    executable = context['executable']
    model_require(isinstance(executable, dict) and set(executable) == {'path', 'resolved_path', 'sha256'} and
                  all(isinstance(executable[key], str) for key in executable) and
                  pathlib.Path(executable['path']).is_absolute() and pathlib.Path(executable['resolved_path']).is_absolute() and
                  executable['sha256'] == dependency(executable['resolved_path']),
                  'input-invalid', 'executable identity differs from dependency evidence')
    command = claude_argv(root, data, executable['path'], context['session_id'], data['role'], role,
                         root / context['settings']['path'], fixed_inputs=fixed, model_binding=binding)
    return command, alignment


def verify_model_run(root, launch_path, launch_sha, delivery_path, delivery_sha, slot, *, feature=None, runtime_root=None):
    """Reconstruct immutable execution/delivery consistency. This never authorizes native execution."""
    capture = EvidenceCapture(root, runtime_root=runtime_root)
    launch_raw = capture.read({'path': launch_path, 'sha256': launch_sha})
    delivery_binding = capture.document({'path': delivery_path, 'sha256': delivery_sha})
    return verify_captured_model_run(capture, launch_raw, delivery_binding, launch_path, launch_sha,
                                     delivery_path, delivery_sha, slot, feature=feature)


def verify_captured_model_run(capture, launch_raw, delivery_binding, launch_path, launch_sha,
                              delivery_path, delivery_sha, slot, *, feature=None):
    """The same closed consistency checks also validate a not-yet-published binding."""
    launch = strict_document(launch_raw, 'model launch')
    model_require(set(delivery_binding) == DELIVERY_BINDING_FIELDS and
                  delivery_binding['schema'] == 'model-delivery-binding/v1' and
                  delivery_binding['transport'] == launch['transport'] and
                  delivery_binding['launch_sha256'] == launch_sha,
                  'input-invalid', 'model delivery linkage is not closed')
    for name in ('selection', 'events', 'delivery', 'execution_context'):
        capture.read(delivery_binding[name])
    selection, events, delivery, context = [capture.document(delivery_binding[name]) for name in
                                           ('selection', 'events', 'delivery', 'execution_context')]
    if context.get('transport') == 'codex-exec':
        return verify_panelist_run(capture, launch_raw, launch, delivery_binding, selection, events, delivery,
                                   context, launch_path, launch_sha, delivery_path, delivery_sha, slot, feature)
    model_require(set(launch) == LAUNCH_FIELDS and launch['transport'] == MODEL_TRANSPORT,
                  'input-invalid', 'protected model launch transport differs')
    model_require(set(context) == EXECUTION_FIELDS, 'input-invalid', 'execution context fields differ')
    helper = captured_model_helper(capture, launch['trusted'])
    helper.validate_selection_record(selection, require_bound=True)
    model_require(all(delivery_binding[key] == selection['binding'][key] == context[key]
                      for key in ('run_id', 'session_id', 'attempt')) and
                  delivery_binding['selection_sha256'] == selection['selection_sha256'],
                  'scope-mismatch', 'delivery binding differs from selection or execution context')
    binding = retrospective_binding(capture, launch, selection, context, helper)
    command, alignment = reconstructed_command(capture, context, binding, feature=feature)
    model_require(launch_raw == canonical_bytes(model_launch_document(binding, command, alignment)),
                  'config-conflict', 'prelaunch record differs from independently reconstructed command/context')
    helper.validate_delivery_record(delivery, selection=selection, events=events, require_actual_id=False)
    model_require(delivery['status'] == 'accepted', 'actual-id-unavailable', 'blocked model delivery cannot be emitted')
    expected_slot = 'main' if selection['role'] in MAIN_MODEL_ROLES else 'reviewers'
    model_require(slot == expected_slot, 'scope-mismatch', 'run-record actor slot differs from selected role')
    return {'actor_slot': slot, 'transport': MODEL_TRANSPORT, 'launch_sha256': launch_sha,
            'delivery_binding_sha256': delivery_sha, 'selection': selection, 'delivery': delivery,
            'events_sha256': delivery_binding['events']['sha256']}


def record_model_delivery(root, output, binding, launch_sha, context_sha, *, transport=MODEL_TRANSPORT,
                          directory_fd=None, verified_policy=None, runtime_root=None):
    with model_output_directory(output, directory_fd) as directory_fd:
        helper_capture = EvidenceCapture(root, runtime_root=runtime_root)
        helper = captured_model_helper(helper_capture, binding['trusted'], runtime=transport == 'codex-exec')
        selection = binding['selection']
        events = {'host': selection['host'], 'cli_version': selection['cli_version'],
                  'selection_sha256': selection['selection_sha256'], 'run_id': binding['run_id'],
                  'session_id': binding['session_id'], 'thread_id': binding['session_id'],
                  'turn_id': 'local-review-attempt-' + str(binding['attempt']),
                  'thread_read': None, 'turn_start': None, 'notifications': []}
        delivery = helper.verify_delivery(selection, events, require_actual_id=binding['require_actual_id'],
                                          **({'transport': 'codex-exec'} if transport == 'codex-exec' else {}))
        refs = {}
        for name, document in (('selection', selection), ('events', events), ('delivery', delivery)):
            filename = 'model-' + name + '.json'
            digest = write_model_record(output, filename, document, directory_fd=directory_fd)
            refs[name] = {'path': (output / filename).relative_to(root).as_posix(), 'sha256': digest}
        document = {'schema': 'model-delivery-binding/v1', 'launch_sha256': launch_sha, 'transport': transport,
                    **refs, 'execution_context': {'path': (output / 'model-execution-context.json').relative_to(root).as_posix(),
                                                   'sha256': context_sha}, 'run_id': binding['run_id'],
                    'session_id': binding['session_id'], 'attempt': binding['attempt'],
                    'selection_sha256': selection['selection_sha256']}
        digest = hashlib.sha256(canonical_bytes(document)).hexdigest()
        capture = EvidenceCapture(root, runtime_root=runtime_root)
        launch_path = (output / 'model-launch.json').relative_to(root).as_posix()
        launch_raw = capture.read({'path': launch_path, 'sha256': launch_sha})
        policy = verify_captured_model_run(capture, launch_raw, document, launch_path, launch_sha,
            (output / 'model-delivery-binding.json').relative_to(root).as_posix(), digest,
            'main' if selection['role'] in MAIN_MODEL_ROLES else 'reviewers')
        # Both transports validate the prepared binding before its create-only publication.
        write_model_record(output, 'model-delivery-binding.json', document, directory_fd=directory_fd)
        if verified_policy is not None:
            verified_policy.update(policy)
        return digest

def model_run_record_cli(argv, *, runtime_root=None):
    parser = argparse.ArgumentParser()
    parser.add_argument('root', type=pathlib.Path)
    for name in ('launch', 'launch-sha256', 'delivery-binding', 'delivery-binding-sha256', 'slot', 'feature'):
        parser.add_argument('--' + name, required=True)
    for name in ('model', 'effort', 'control', 'applied'):
        parser.add_argument('--assert-' + name)
    args = parser.parse_args(argv)
    result = verify_model_run(args.root, args.launch, args.launch_sha256, args.delivery_binding,
                              args.delivery_binding_sha256, args.slot, feature=args.feature, runtime_root=runtime_root)
    selected = result['selection']['resolved']
    for value, expected in ((args.assert_model, selected['native_id']), (args.assert_effort, selected['effort']),
                            (args.assert_control, 'flag'), (args.assert_applied, selected['effort'])):
        model_require(value is None or value == expected, 'config-conflict', 'explicit actor metadata contradicts model evidence')
    raw = sys.stdin.buffer.read(MAX_LAUNCH_RECORD + 1)
    model_require(len(raw) <= MAX_LAUNCH_RECORD, 'input-invalid', 'run record exceeds its bound')
    record = strict_document(raw, 'run record')
    model_require(record.get('feature') == args.feature and isinstance(record.get('model_ids'), dict),
                  'scope-mismatch', 'run-record feature or model slots are invalid')
    record['schema'] = 'sdd-run-record/v2'
    record['run_id'] = result['selection']['binding']['run_id']
    record['model_ids'][args.slot] = selected['native_id']
    record.setdefault('effort', {name: {'effort_requested': None, 'effort_applied': None,
                                      'effort_degraded_reason': 'effort-not-requested'} for name in ('main', 'reviewers')})
    record['effort'][args.slot] = {'effort_requested': selected['effort'], 'effort_applied': selected['effort'],
                                 'effort_degraded_reason': None}
    record['model_policy'] = result
    print(json.dumps(record, ensure_ascii=False, indent=2))



PANELIST_PROMPT = 'You are an independent panelist reviewing a software implementation. You are\nrunning BLIND: you have not seen any other panelist\'s verdict, the primary\nevaluator\'s verdict, or any prior review feedback on this task.\n\nYour role is READ-ONLY. You must not suggest, write, or edit code. You must\nnot approve or set any task status. Return a structured verdict JSON only.\n\n## Input\n\nThe sanitized input bundle follows this message. Review it for correctness,\ncompleteness, and adherence to the stated requirements and design.\n\n## Output Format\n\nYour ENTIRE reply MUST be a single bare JSON object matching this exact\nschema. The first character of your reply MUST be `{` and the last\ncharacter MUST be `}`. Do not include any prose before or after it, and\ndo not wrap it in a Markdown code fence (no ``` of any kind):\n\n{\n  "schema": "cross-model-verdict/v1",\n  "task_id": "<task_id>",\n  "feature": "<feature>",\n  "vendor": "openai",\n  "model": "<model>",\n  "verdict": "PASS" | "NEEDS_WORK",\n  "findings": [\n    { "severity": "Critical" | "Major" | "Minor", "ref": "<file:line or section>", "note": "<description>" }\n  ],\n  "blind": true,\n  "input_digest": "<digest-from-bundle-header>",\n  "consent": { "kind": "<consent-kind>", "ref": "<ref>" }\n}\n\nRules:\n- verdict MUST be "PASS" or "NEEDS_WORK".\n- findings MUST be an array (empty [] if none).\n- blind MUST be true (boolean, not string).\n- input_digest: copy the value from the "# input_digest:" comment in the bundle header.\n- consent.kind: copy from the "# consent:" comment in the bundle header.\n- consent.ref: the tasks.md flag or SDD_SUDO reference from the bundle.\n- Do not include any text outside the JSON object.\n- Do not wrap the JSON object in a Markdown code fence.\n'

def strip_code_fences(text):
    # Models wrap replies in ```json fences constantly, regardless of what
    # the prompt asks for. The brace-balancer below does not depend on
    # this (it only tracks '{'..matching '}'), but stripping fence lines
    # first keeps diagnostics free of fence noise.
    return re.sub(r'```[ \t]*[A-Za-z0-9_-]*[ \t]*\r?\n|```', '', text)

def find_json_object_candidates(text):
    """Return each top-level brace-balanced '{...}' substring of `text`,
    in order of appearance. String literals (and their backslash escapes)
    are tracked so a '}' inside a JSON string does not close a candidate
    early. Nested objects are not yielded separately -- only the outermost
    '{' of each candidate starts a new scan."""
    candidates = []
    n = len(text)
    i = 0
    while i < n:
        if text[i] != '{':
            i += 1
            continue
        start = i
        depth = 0
        in_string = False
        escape = False
        j = i
        closed_at = -1
        while j < n:
            c = text[j]
            if in_string:
                if escape:
                    escape = False
                elif c == '\\':
                    escape = True
                elif c == '"':
                    in_string = False
            else:
                if c == '"':
                    in_string = True
                elif c == '{':
                    depth += 1
                elif c == '}':
                    depth -= 1
                    if depth == 0:
                        closed_at = j
                        break
            j += 1
        if closed_at >= 0:
            candidates.append(text[start:closed_at + 1])
            i = closed_at + 1
        else:
            # Unterminated from this '{' (e.g. a truncated echo) -- advance
            # past it and keep scanning for the next candidate.
            i = start + 1
    return candidates

PANELIST_CONTEXT_FIELDS = frozenset(('schema', 'transport', 'role', 'run_id', 'session_id', 'attempt',
    'task_id', 'feature', 'spec_root', 'bundle', 'input_digest', 'consent_kind', 'consent_result', 'scratch',
    'executable', 'dependencies', 'policy_environment', 'timeout_seconds'))
PANELIST_LAUNCH_FIELDS = frozenset(('schema', 'transport', 'controls', 'pins', 'trusted', 'role', 'host',
    'run_id', 'session_id', 'attempt', 'require_actual_id', 'selection_sha256', 'native_model', 'effort',
    'effort_control', 'effort_carrier', 'model_argv', 'effort_argv', 'argv', 'argv_sha256', 'timeout_seconds'))
PANELIST_CONSENT_FIELDS = frozenset(('schema', 'status', 'task_id', 'feature', 'kind', 'bundle_sha256',
                                    'input_digest', 'gate', 'wrapper'))
PANELIST_SCRIPTS = 'plugins/sdd-quality-loop/scripts/'
PAIRED_DRIVER = 'plugins/sdd-review-loop/scripts/validate-nontty-spec-launch.py'
PANELIST_KEYS = ('SDD_EVIDENCE_KEY', 'SDD_SUDO_KEY', 'SDD_SUDO_KEY_FILE')
MAX_NATIVE_EXECUTABLE = 512 * 1024 * 1024


def panelist_bundle(raw, *, task, feature, kind, expected_digest):
    """Validate the existing preparation format over the exact captured bytes, once."""
    model_require(len(raw) <= MAX_LAUNCH_RECORD and b'\n\n' in raw, 'input-invalid',
                  'panelist bundle has no bounded header/body boundary')
    header, body = raw.split(b'\n\n', 1)
    lines = header.decode('utf-8').split('\n')
    model_require(lines[0] == '# Panelist Input Bundle', 'input-invalid', 'panelist bundle header is invalid')
    values = {}
    for name in ('task_id', 'feature', 'input_digest', 'consent'):
        found = [line[len('# ' + name + ': '):] for line in lines if line.startswith('# ' + name + ': ')]
        model_require(len(found) == 1, 'input-invalid', 'panelist bundle header is missing or duplicated')
        values[name] = found[0]
    digest = hashlib.sha256(body[:-1] if body.endswith(b'\n') else body).hexdigest()
    model_require(values == {'task_id': task, 'feature': feature, 'consent': kind,
                              'input_digest': expected_digest} and digest == expected_digest,
                  'scope-mismatch', 'panelist bundle identity, body digest or consent differs')
    return values


def panelist_attempt_directory(context):
    model_require(isinstance(context['task_id'], str) and re.fullmatch(r'T-[0-9]{3}', context['task_id']) and
                  isinstance(context['feature'], str) and re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*', context['feature']),
                  'input-invalid', 'panelist task or feature is invalid')
    spec_root = control_path_text(context['spec_root'])
    model_require(context['role'] in ('panelist-gpt', 'panelist-gemini'), 'scope-mismatch', 'invalid panelist role')
    key = hashlib.sha256(canonical_bytes({name: context[name] for name in
                                         ('run_id', 'session_id', 'attempt')})).hexdigest()
    vendor = 'openai' if context['role'] == 'panelist-gpt' else 'google'
    return spec_root + '/' + context['feature'] + '/verification/' + context['task_id'] + '.panelist-' + vendor + '/' + key


def panelist_argv(executable, selection, scratch):
    resolved = selection['resolved']
    return [executable, 'exec', '--model', resolved['native_id'], '-c',
            'model_reasoning_effort=' + resolved['effort'], '--sandbox', 'read-only',
            '--skip-git-repo-check', '-C', scratch, '-']


def panelist_launch_document(validation, command, timeout):
    selected = validation['selection']
    resolved = selected['resolved']
    model_require(validation['role'] == 'panelist-gpt' and validation['host'] == 'codex-cli' and
                  type(timeout) is int and 0 < timeout <= 2147483647,
                  'input-invalid', 'selected panelist transport or timeout is invalid')
    document = {name: validation[name] for name in ('controls', 'pins', 'trusted', 'role', 'host',
        'run_id', 'session_id', 'attempt', 'require_actual_id')}
    document.update(schema='model-launch-binding/v1', transport='codex-exec',
        selection_sha256=selected['selection_sha256'], native_model=resolved['native_id'],
        effort=resolved['effort'], effort_control=resolved['effort_control'], effort_carrier='config',
        model_argv=['--model', resolved['native_id']], effort_argv=['-c', 'model_reasoning_effort=' + resolved['effort']],
        argv=list(command), argv_sha256=hashlib.sha256(canonical_bytes(command)).hexdigest(), timeout_seconds=timeout)
    return document


def panelist_runtime_paths(gate, wrapper):
    model_require(gate in (PANELIST_SCRIPTS + 'prepare-panelist-input.sh',
                           PANELIST_SCRIPTS + 'prepare-panelist-input.ps1'),
                  'input-invalid', 'consent authority path is not installed')
    extension = '.ps1' if gate.endswith('.ps1') else '.sh'
    model_require(wrapper == PANELIST_SCRIPTS + 'run-panelist-gpt' + extension,
                  'scope-mismatch', 'selected wrapper differs from consent authority or vendor')
    # The selected shell dispatch occurs before the legacy shell-common import.
    return sorted({*TRUSTED_MODEL_RUNTIME, PAIRED_DRIVER, gate, wrapper})


def verify_panelist_run(capture, launch_raw, launch, linkage, selection, events, delivery, context,
                         launch_path, launch_sha, delivery_path, delivery_sha, slot, feature):
    model_require(set(context) == PANELIST_CONTEXT_FIELDS and context['schema'] == 'model-execution-context/v1' and
                  context['transport'] == launch['transport'] == linkage['transport'] == 'codex-exec' and
                  set(launch) == PANELIST_LAUNCH_FIELDS and slot == 'reviewers',
                  'input-invalid', 'panelist execution and launch contexts are not closed and matched')
    helper = captured_model_helper(capture, launch['trusted'], runtime=True)
    helper.validate_selection_record(selection, require_bound=True)
    model_require(context['role'] == 'panelist-gpt' and selection['host'] == 'codex-cli' and
                  all(linkage[key] == selection['binding'][key] == context[key]
                      for key in ('run_id', 'session_id', 'attempt')) and
                  linkage['selection_sha256'] == selection['selection_sha256'] and
                  (feature is None or context['feature'] == feature),
                  'scope-mismatch', 'panelist selection differs from execution identity or feature')
    folder = panelist_attempt_directory(context)
    expected_refs = {'selection': 'model-selection.json', 'events': 'model-events.json',
                     'delivery': 'model-delivery.json', 'execution_context': 'model-execution-context.json'}
    model_require(launch_path == folder + '/model-launch.json' and
                  delivery_path == folder + '/model-delivery-binding.json' and
                  all(linkage[name]['path'] == folder + '/' + filename for name, filename in expected_refs.items()),
                  'scope-mismatch', 'panelist records differ from the immutable attempt directory')
    for name, filename in (('bundle', 'model-bundle.txt'), ('consent_result', 'model-consent.json'),
                           ('dependencies', 'dependencies.json')):
        model_require(context[name]['path'] == folder + '/' + filename, 'scope-mismatch',
                      'panelist context artifact differs from its immutable attempt')
    bundle = capture.read(context['bundle'])
    panelist_bundle(bundle, task=context['task_id'], feature=context['feature'], kind=context['consent_kind'],
                     expected_digest=context['input_digest'])
    consent, dependencies = capture.document(context['consent_result']), capture.document(context['dependencies'])
    model_require(set(consent) == PANELIST_CONSENT_FIELDS and consent['schema'] == 'model-panelist-consent/v1' and
                  consent['status'] == 'accepted-before-send' and
                  consent['task_id'] == context['task_id'] and consent['feature'] == context['feature'] and
                  consent['kind'] == context['consent_kind'] and consent['kind'] in ('human-flag', 'sudo') and
                  consent['bundle_sha256'] == context['bundle']['sha256'] and
                  consent['input_digest'] == context['input_digest'],
                  'scope-mismatch', 'captured consent result differs from the original bundle and task')
    capture.read_runtime(consent['gate'])
    capture.read_runtime(consent['wrapper'])
    executable = context['executable']
    model_require(isinstance(executable, dict) and set(executable) == {'path', 'resolved_path', 'sha256'} and
                  all(isinstance(value, str) for value in executable.values()) and
                  pathlib.Path(executable['path']).is_absolute() and
                  pathlib.Path(executable['resolved_path']).is_absolute() and
                  SHA256.fullmatch(executable['sha256']) is not None and
                  all('codex-sync' not in pathlib.Path(executable[key]).name for key in ('path', 'resolved_path')),
                  'input-invalid', 'panelist executable identity is invalid')
    runtime = panelist_runtime_paths(consent['gate']['path'], consent['wrapper']['path'])
    expected_keys = {str(capture.runtime_root / name) for name in runtime} | {executable['resolved_path']}
    model_require(set(dependencies) == expected_keys and
                  dependencies.get(executable['resolved_path']) == executable['sha256'],
                  'input-invalid', 'panelist dependency inventory differs from the fixed runtime and executable')
    for name in runtime:
        raw = capture.read_runtime({'path': name, 'sha256': dependencies[str(capture.runtime_root / name)]})
        model_require(hashlib.sha256(raw).hexdigest() == dependencies[str(capture.runtime_root / name)],
                      'input-invalid', 'panelist runtime raw pin differs')
    model_require(isinstance(context['scratch'], str) and pathlib.Path(context['scratch']).is_absolute() and
                  str(pathlib.Path(context['scratch'])) == context['scratch'] and
                  '..' not in pathlib.Path(context['scratch']).parts and
                  pathlib.Path(context['scratch']) != capture.root,
                  'input-invalid', 'panelist scratch identity is invalid')
    validation = immutable_launch_validation(capture, launch, selection, context, helper,
                                              role='panelist-gpt', host='codex-cli', runtime=True)
    command = panelist_argv(executable['path'], selection, context['scratch'])
    model_require(launch_raw == canonical_bytes(panelist_launch_document(validation, command, context['timeout_seconds'])),
                  'config-conflict', 'panelist launch differs from reconstructed execution context')
    helper.validate_delivery_record(delivery, selection=selection, events=events,
                                     require_actual_id=False, transport='codex-exec')
    model_require(delivery['status'] == 'accepted', 'actual-id-unavailable', 'blocked panelist delivery cannot be emitted')
    return {'actor_slot': 'reviewers', 'transport': 'codex-exec', 'launch_sha256': launch_sha,
            'delivery_binding_sha256': delivery_sha, 'selection': selection, 'delivery': delivery,
            'events_sha256': linkage['events']['sha256']}


def panelist_options(argv):
    permitted = {'--vendor', '--shell', '--task', '--feature', '--input', '--spec-root', '--digest', '--consent',
                 '--model', '--effort', '--model-controls', '--model-controls-sha256', '--run-id', '--session-id'}
    options = {}
    while argv:
        model_require(len(argv) >= 2 and argv[0] in permitted and argv[0] not in options,
                      'input-invalid', 'unknown, duplicate or incomplete selected panelist argument')
        options[argv[0]], argv = argv[1], argv[2:]
    required = permitted - {'--model', '--effort', '--spec-root', '--digest', '--consent'}
    model_require(required <= set(options) and all(isinstance(v, str) and v for v in options.values()),
                  'input-invalid', 'selected panelist arguments must be supplied together')
    options.setdefault('--spec-root', 'specs')
    options.setdefault('--consent', 'human-flag')
    model_require(options['--vendor'] in ('gpt', 'gemini') and options['--shell'] in ('bash', 'powershell') and
                  options['--consent'] in ('human-flag', 'sudo') and
                  all(MODEL_ID.fullmatch(options[key]) is not None for key in ('--run-id', '--session-id')),
                  'input-invalid', 'selected panelist vendor, shell, identity or consent is invalid')
    control_path_text(options['--input'])
    control_path_text(options['--model-controls'])
    model_require(SHA256.fullmatch(options['--model-controls-sha256']) is not None,
                  'input-invalid', 'selected controls require a raw SHA256')
    return options


def panelist_consent(root, options, environment, temporary, *, runtime_root=None):
    """Invoke the existing authority; the sentinel does not authorize substituted bundle bytes."""
    runtime_root = root if runtime_root is None else pathlib.Path(runtime_root)
    ext = '.sh' if options['--shell'] == 'bash' else '.ps1'
    gate = PANELIST_SCRIPTS + 'prepare-panelist-input' + ext
    gate_raw = read_regular(runtime_root / gate, MAX_LAUNCH_RECORD, 'panelist consent authority')
    empty = temporary / 'consent-input.txt'
    empty.write_bytes(b'')
    sentinel = temporary / 'consent-check.txt'
    if ext == '.sh':
        executable = shutil.which('bash', path=environment.get('PATH'))
    else:
        executable = environment.get('SDD_TEST_PWSH') or shutil.which('pwsh', path=environment.get('PATH'))
    if executable is None:
        raise ModelLaunchError('input-invalid', 'panelist consent authority shell is unavailable')
    command = [executable, str(runtime_root / gate)] if ext == '.sh' else [executable, '-NoProfile', '-File', str(runtime_root / gate)]
    command += ['--task', options['--task'], '--feature', options['--feature'], '--spec-root', options['--spec-root'],
                '--tasks-file', str(root / options['--spec-root'] / options['--feature'] / 'tasks.md'),
                '--project-root', str(root), '--input', str(empty), '--out', str(sentinel)]
    try:
        with tempfile.TemporaryFile() as output, tempfile.TemporaryFile() as errors:
            result = subprocess.run(command, cwd=root, env=environment, stdin=subprocess.DEVNULL,
                                    stdout=output, stderr=errors, timeout=60, check=False)
        model_require(result.returncode == 0, 'input-invalid', 'panelist consent authority denied this task')
        raw = read_regular(sentinel, MAX_LAUNCH_RECORD, 'panelist consent recheck')
        header = raw.split(b'\n\n', 1)[0].decode('utf-8')
        match = re.findall(r'^# input_digest: ([0-9a-f]{64})$', header, re.MULTILINE)
        model_require(len(match) == 1, 'input-invalid', 'panelist consent result has no unique digest')
        panelist_bundle(raw, task=options['--task'], feature=options['--feature'], kind=options['--consent'],
                         expected_digest=match[0])
        model_require(read_regular(runtime_root / gate, MAX_LAUNCH_RECORD, 'panelist consent authority') == gate_raw,
                      'input-invalid', 'panelist consent source changed during recheck')
    except (OSError, subprocess.TimeoutExpired):
        raise ModelLaunchError('input-invalid', 'panelist consent authority did not complete') from None
    return {'path': gate, 'sha256': hashlib.sha256(gate_raw).hexdigest()}


def panelist_native(command, scratch, environment, prompt, timeout):
    """Bound one owned process group and remove its descendants on every outcome."""
    with tempfile.TemporaryFile() as output, tempfile.TemporaryFile() as errors, tempfile.TemporaryFile() as stdin:
        stdin.write(prompt)
        stdin.seek(0)
        process = subprocess.Popen(command, cwd=scratch, env=environment, stdin=stdin,
                                   stdout=output, stderr=errors, start_new_session=True)
        try:
            try:
                code = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                raise ModelLaunchError('input-invalid', 'panelist native execution exceeded its timeout') from None
            model_require(code == 0, 'input-invalid', 'panelist native execution failed')
            model_require(output.seek(0, os.SEEK_END) <= MAX_LAUNCH_RECORD,
                          'input-invalid', 'panelist output exceeds its bound')
            output.seek(0)
            return output.read()
        finally:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()


def panelist_verdict(raw, options, digest):
    cleaned = strip_code_fences(raw.decode('utf-8', errors='replace'))
    verdict = None
    for candidate in find_json_object_candidates(cleaned):
        try:
            value = strict_document(candidate.encode('utf-8'), 'native verdict')
        except ValueError:
            continue
        if value.get('schema') == 'cross-model-verdict/v1':
            verdict = value
    required = {'schema', 'task_id', 'feature', 'vendor', 'model', 'verdict', 'findings', 'blind', 'input_digest', 'consent'}
    if not isinstance(verdict, dict):
        raise ModelLaunchError('input-invalid', 'native panelist returned no valid verdict')
    model_require(required <= set(verdict), 'input-invalid', 'native panelist returned no valid verdict')
    model_require(verdict['blind'] is True and verdict['verdict'] in ('PASS', 'NEEDS_WORK') and
                  isinstance(verdict['findings'], list) and isinstance(verdict['model'], str) and
                  verdict['task_id'] == options['--task'] and verdict['feature'] == options['--feature'] and
                  verdict['input_digest'] == digest and isinstance(verdict['consent'], dict) and
                  verdict['consent'].get('kind') == options['--consent'],
                  'scope-mismatch', 'native verdict differs from the admitted bundle and consent')
    verdict['vendor'] = 'openai'
    return verdict


@contextmanager
def panelist_output_directories(root, relative):
    """Create one attempt through no-follow descriptors and keep all writes anchored there."""
    control_path_text(relative)
    required = ('O_NOFOLLOW', 'O_DIRECTORY', 'O_NONBLOCK')
    model_require(all(isinstance(getattr(os, name, None), int) for name in required) and
                  all(call in os.supports_dir_fd for call in (os.open, os.mkdir, os.rename, os.unlink)) and
                  os.listdir in os.supports_fd, 'input-invalid', 'safe panelist output primitives are unavailable')
    flags = os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY | os.O_NONBLOCK | getattr(os, 'O_CLOEXEC', 0)
    descriptors = []
    try:
        current = os.open(root.anchor, flags)
        descriptors.append(current)
        for part in root.parts[1:]:
            model_require(part in os.listdir(current), 'input-invalid', 'output root is not canonical')
            current = os.open(part, flags, dir_fd=current)
            descriptors.append(current)
        parts = pathlib.PurePosixPath(relative).parts
        verification = None
        for index, part in enumerate(parts):
            if index == len(parts) - 1:
                try:
                    os.mkdir(part, mode=0o700, dir_fd=current)
                except FileExistsError:
                    raise ModelLaunchError('resume-conflict', 'panelist attempt output already exists') from None
            elif part not in os.listdir(current):
                try:
                    os.mkdir(part, mode=0o700, dir_fd=current)
                except FileExistsError:
                    pass  # The following no-follow open still validates a concurrent creation.
            current = os.open(part, flags, dir_fd=current)
            descriptors.append(current)
            if index == len(parts) - 3:
                verification = current
        model_require(verification is not None, 'input-invalid', 'panelist verification directory is absent')
        yield current, verification
    except OSError:
        raise ModelLaunchError('input-invalid', 'panelist output path could not be safely created') from None
    finally:
        for descriptor in reversed(descriptors):
            os.close(descriptor)


def model_panelist_run(argv, *, runtime_root=None):
    options = panelist_options(argv)
    root = pathlib.Path.cwd().resolve()
    runtime_root = root if runtime_root is None else pathlib.Path(runtime_root).resolve()
    environment = dict(os.environ)
    timeout_text = environment.get('SDD_PANELIST_TIMEOUT', '600')
    model_require(re.fullmatch(r'[0-9]+', timeout_text) is not None and 0 < int(timeout_text) <= 2147483647,
                  'input-invalid', 'panelist timeout must be a positive whole number of seconds')
    timeout = int(timeout_text)
    role = 'panelist-' + options['--vendor']
    host = 'codex-cli' if role == 'panelist-gpt' else 'gemini-cli'
    scope = {'task_id': options['--task'], 'feature': options['--feature'], 'spec_root': options['--spec-root'],
             'role': role, 'run_id': options['--run-id'], 'session_id': options['--session-id'], 'attempt': 1}
    panelist_attempt_directory(scope)  # Validate path identities before authority or external dispatch.
    bundle = read_regular(root / options['--input'], MAX_LAUNCH_RECORD, 'panelist input bundle')
    if '--digest' not in options:
        values = re.findall(rb'^# input_digest: ([0-9a-f]{64})$', bundle.split(b'\n\n', 1)[0], re.MULTILINE)
        model_require(len(values) == 1, 'input-invalid', 'panelist bundle digest is absent or duplicated')
        options['--digest'] = values[0].decode('ascii')
    panelist_bundle(bundle, task=scope['task_id'], feature=scope['feature'], kind=options['--consent'],
                     expected_digest=options['--digest'])
    with tempfile.TemporaryDirectory(prefix='sdd-selected-panelist-') as directory:
        scratch = pathlib.Path(directory).resolve()
        gate = panelist_consent(root, options, environment, scratch, runtime_root=runtime_root)
        validation = checked_controls_validation(model_launch_controls(root, role, scope['run_id'], scope['session_id'],
            options['--model-controls'], options['--model-controls-sha256'], environment, host=host,
            runtime_root=runtime_root), role=role, host=host,
            run_id=scope['run_id'], session_id=scope['session_id'], controls=options['--model-controls'],
            controls_sha256=options['--model-controls-sha256'])
        model_require(role == 'panelist-gpt', 'model-unavailable', 'trusted Gemini native mapping is unavailable')
        selection = validation['selection']
        model_require(all(name not in options or options[name] == selection['resolved'][field] for name, field in
                          (('--model', 'native_id'), ('--effort', 'effort'))),
                      'config-conflict', 'explicit panelist model or effort differs from selected controls')
        executable_text = environment.get('SDD_PANELIST_CODEX_CMD') or shutil.which('codex', path=environment.get('PATH'))
        if not executable_text:
            raise ModelLaunchError('model-unavailable', 'Codex executable is unavailable')
        executable = pathlib.Path(executable_text).absolute()
        resolved = executable.resolve(strict=True)
        model_require('codex-sync' not in executable.name and 'codex-sync' not in resolved.name,
                      'input-invalid', 'codex-sync is not a panelist native executable')
        executable_sha = read_regular(resolved, MAX_NATIVE_EXECUTABLE, 'native executable', digest_only=True)
        scope['attempt'] = validation['attempt']
        relative = panelist_attempt_directory(scope)
        output = root / relative
        with panelist_output_directories(root, relative) as (output_fd, verification_fd):
            write_model_bytes(output, 'model-bundle.txt', bundle, directory_fd=output_fd)
            ext = '.sh' if options['--shell'] == 'bash' else '.ps1'
            wrapper = local_reference(runtime_root, runtime_root / (PANELIST_SCRIPTS + 'run-panelist-gpt' + ext))
            consent = {'schema': 'model-panelist-consent/v1', 'status': 'accepted-before-send',
                       'task_id': scope['task_id'], 'feature': scope['feature'], 'kind': options['--consent'],
                       'bundle_sha256': hashlib.sha256(bundle).hexdigest(), 'input_digest': options['--digest'],
                       'gate': gate, 'wrapper': wrapper}
            write_model_record(output, 'model-consent.json', consent, directory_fd=output_fd)
            dependencies = {str(runtime_root / name): hashlib.sha256(read_regular(runtime_root / name, MAX_LAUNCH_RECORD,
                             'panelist runtime')).hexdigest() for name in panelist_runtime_paths(gate['path'], wrapper['path'])}
            dependencies[str(resolved)] = executable_sha
            write_model_record(output, 'dependencies.json', dependencies, directory_fd=output_fd)
            context = {'schema': 'model-execution-context/v1', 'transport': 'codex-exec', **scope,
                       'bundle': local_reference(root, output / 'model-bundle.txt'), 'input_digest': options['--digest'],
                       'consent_kind': options['--consent'], 'consent_result': local_reference(root, output / 'model-consent.json'),
                       'scratch': str(scratch), 'executable': {'path': str(executable), 'resolved_path': str(resolved),
                                                            'sha256': executable_sha},
                       'dependencies': local_reference(root, output / 'dependencies.json'),
                       'policy_environment': policy_environment(environment, runtime_root), 'timeout_seconds': timeout}
            context_sha = write_model_record(output, 'model-execution-context.json', context, directory_fd=output_fd)
            command = panelist_argv(str(executable), selection, str(scratch))
            launch_sha = write_model_record(output, 'model-launch.json', panelist_launch_document(validation, command, timeout),
                                            directory_fd=output_fd)
            # Recheck admitted raw source/control identities before native dispatch; no re-selection after execution.
            for base, references in ((root, [validation['controls'], *validation['pins']]),
                                     (runtime_root, [*validation['trusted'], gate, wrapper])):
                for ref in references:
                    model_require(hashlib.sha256(read_regular(base / ref['path'], MAX_LAUNCH_RECORD,
                                  'panelist prelaunch input')).hexdigest() == ref['sha256'],
                                  'input-invalid', 'panelist prelaunch source changed')
            child_environment = {key: value for key, value in environment.items() if key not in PANELIST_KEYS}
            prompt = PANELIST_PROMPT.encode('utf-8') + b'\n\n## Sanitized Input Bundle\n\n' + bundle
            raw = panelist_native(command, scratch, child_environment, prompt, timeout)
            verdict = panelist_verdict(raw, options, options['--digest'])
            policy: dict[str, Any] = {}
            record_model_delivery(root, output, validation, launch_sha, context_sha, transport='codex-exec',
                                  directory_fd=output_fd, verified_policy=policy, runtime_root=runtime_root)
            verdict['model_policy'] = policy
            verdict_name = scope['task_id'] + '.panelist-openai.verdict.json'
            write_model_record(output, 'verdict.json', verdict, directory_fd=output_fd)
            # Atomic anchored publication leaves the previous successful verdict intact on failure.
            temporary_name = verdict_name + '.' + uuid.uuid4().hex + '.tmp'
            try:
                write_model_bytes(output.parent.parent, temporary_name, canonical_bytes(verdict) + b'\n',
                                  directory_fd=verification_fd)
                os.replace(temporary_name, verdict_name, src_dir_fd=verification_fd, dst_dir_fd=verification_fd)
            finally:
                try:
                    os.unlink(temporary_name, dir_fd=verification_fd)
                except FileNotFoundError:
                    pass
    return 0


def model_panelist_cli(argv):
    try:
        return model_panelist_run(argv, runtime_root=installed_model_runtime_root())
    except (ValueError, OSError, KeyError, TypeError, UnicodeError):
        error = sys.exc_info()[1]
        reason = error.reason if isinstance(error, ModelLaunchError) else 'input-invalid'
        message = str(error) if isinstance(error, ModelLaunchError) else 'Selected panelist inputs or execution were rejected.'
        sys.stderr.buffer.write(canonical_bytes({'schema': 'model-policy-error/v1', 'reason': reason,
                                                 'message': message[:512]}) + b'\n')
        return 2


def main():
    if sys.argv[1:2] == ['model-panelist-run']:
        raise SystemExit(model_panelist_cli(sys.argv[2:]))
    if sys.argv[1:2] == ['model-run-record']:
        return model_run_record_cli(sys.argv[2:])
    if sys.argv[1:2] == ['model-installed-run-record']:
        return model_run_record_cli(sys.argv[2:], runtime_root=installed_model_runtime_root())
    parser = argparse.ArgumentParser()
    parser.add_argument('phase', choices=('preflight', 'postflight', 'fixed-binding'))
    parser.add_argument('root', type=pathlib.Path)
    parser.add_argument('invocation', type=pathlib.Path)
    parser.add_argument('transcript', type=pathlib.Path, nargs='?')
    parser.add_argument('--fixed-input-record', type=pathlib.Path)
    parser.add_argument('--fixed-input-snapshot', type=pathlib.Path)
    parser.add_argument('--prompt', type=pathlib.Path)
    parser.add_argument('--wrapper', type=pathlib.Path)
    parser.add_argument('--receipt', type=pathlib.Path)
    args = parser.parse_args()
    root = args.root.resolve()
    require(args.invocation.is_file(), 'invocation missing')
    if args.phase == 'fixed-binding':
        require(args.fixed_input_record is not None and args.fixed_input_snapshot is not None,
                'fixed input record and snapshot required')
        binding = fixed_input_binding(root, load(args.invocation),
                                      args.fixed_input_record, args.fixed_input_snapshot)
        print(json.dumps([binding[key] for key in ('approval_reference', 'progress_reference')
                          if key in binding], sort_keys=True))
        return
    require(args.transcript is not None, 'transcript required')
    require(args.fixed_input_record is None and args.fixed_input_snapshot is None,
            'fixed binding arguments require fixed-binding phase')
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
