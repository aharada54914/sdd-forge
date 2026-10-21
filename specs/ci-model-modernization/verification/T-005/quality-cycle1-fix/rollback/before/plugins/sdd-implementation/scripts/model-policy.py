#!/usr/bin/env python3
"""Read-only host model discovery and strict model-observation/v1 validation (T-004).

Standard library only. Discovery never starts a thread/turn, never logs in or refreshes credentials,
and never persists raw native prose, account data or paths. Selection, binding and launch are downstream.
"""
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import json
import os
from pathlib import Path
import queue
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time

OBSERVATION_SCHEMA = 'model-observation/v1'
ERROR_SCHEMA = 'model-policy-error/v1'
HOSTS = ('claude-code', 'codex-cli', 'copilot-cli', 'gemini-cli')
EFFORTS = ('low', 'medium', 'high', 'xhigh')
SOURCES = ('live-discovery', 'verified-configuration', 'unsupported')
STATUSES = ('complete', 'incomplete', 'unavailable')
SCOPE_KINDS = ('account', 'client')
PURPOSES = ('diagnostic', 'launch')
REASONS = ('config-invalid', 'config-conflict', 'native-precedence-conflict', 'discovery-unavailable',
           'discovery-incomplete', 'discovery-stale', 'scope-mismatch', 'model-unavailable', 'model-unverified',
           'model-tier-unavailable', 'effort-unavailable', 'budget-unverifiable', 'resume-conflict',
           'actual-id-unavailable', 'actual-id-mismatch', 'input-invalid')
OBSERVATION_FIELDS = frozenset(('schema', 'host', 'cli_version', 'scope_id', 'scope_kind', 'purpose', 'observed_at',
                                'source', 'status', 'models', 'reason', 'observation_sha256'))
MODEL_FIELDS = frozenset(('native_id', 'efforts', 'available'))
ERROR_FIELDS = frozenset(('schema', 'reason', 'message'))
MAX_TEXT = 512
ID_RE = re.compile(r'[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}')
VERSION_RE = re.compile(r'[!-~](?:[ -~]{0,126}[!-~])?')
UTC_RE = re.compile(r'([0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2})(?:\.([0-9]+))?Z')
SHA_RE = re.compile(r'[0-9a-f]{64}')
UNAVAILABLE_VERSION = 'unavailable'

# Conservative native transport bounds (fail closed when exceeded).
VERSION_TIMEOUT_SECONDS = 15
MAX_VERSION_BYTES = 256  # VERSION_RE allows 128 ASCII chars; room for surrounding whitespace/CRLF only
REQUEST_TIMEOUT_SECONDS = 15
OPERATION_TIMEOUT_SECONDS = 60
MAX_LINE_BYTES = 4 * 1024 * 1024
MAX_OPERATION_BYTES = 16 * 1024 * 1024
MAX_PAGES = 100
MAX_CURSOR_CHARS = 4096
CLEANUP_WAIT_SECONDS = 5
CLIENT_INFO = {'name': 'sdd-model-policy', 'version': '1'}


class PolicyError(ValueError):
    """Typed model-policy-error/v1 failure; optional observation never enters the envelope."""

    def __init__(self, reason, message, *, observation=None):
        if not isinstance(reason, str) or reason not in REASONS:
            raise ValueError('unknown model-policy error reason')
        if not _text(message):
            raise ValueError('model-policy error message must be bounded nonblank text')
        if observation is not None:
            validate_observation_record(observation)
        super().__init__(message)
        self.reason = reason
        self.message = message
        self.observation = observation

    def as_dict(self):
        return {'schema': ERROR_SCHEMA, 'reason': self.reason, 'message': self.message}


def _invalid(message):
    return PolicyError('input-invalid', message)


def _text(value, limit=MAX_TEXT):
    return isinstance(value, str) and 0 < len(value) <= limit and bool(value.strip())


def _member(value, allowed):
    return isinstance(value, str) and value in allowed


def canonical(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':'),
                      ensure_ascii=False, allow_nan=False).encode('utf-8')


def strict_json(raw):
    def unique(pairs):
        result = {}
        for key, item in pairs:
            if key in result:
                raise ValueError('duplicate JSON key')
            result[key] = item
        return result

    def nonfinite(_value):
        raise ValueError('nonfinite JSON number')

    try:
        if isinstance(raw, bytes):
            raw = raw.decode('utf-8', errors='strict')
        if not isinstance(raw, str):
            raise ValueError('JSON text required')
        result = json.loads(raw, object_pairs_hook=unique, parse_constant=nonfinite)
        if not isinstance(result, dict):
            raise ValueError('JSON object required')
        canonical(result)  # Also rejects overflow such as 1e999.
    except (ValueError, RecursionError):
        raise _invalid('Input is not one strict UTF-8 JSON object.') from None
    return result


def observation_digest(record):
    return hashlib.sha256(canonical({k: v for k, v in record.items() if k != 'observation_sha256'})).hexdigest()


_EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)


def _instant(seconds_moment, fraction):
    """Exact instant as (whole epoch seconds, fraction digits without trailing zeros).

    Tuples compare exactly: equal whole seconds fall back to lexicographic digit order, which is numeric order
    once trailing zeros are stripped. No float, Decimal context or sub-microsecond truncation is involved.
    """
    return (seconds_moment - _EPOCH) // timedelta(seconds=1), fraction.rstrip('0')


def _parse_utc(value):
    """Return the exact instant of an RFC 3339 UTC-Z timestamp with any number of fractional digits."""
    match = UTC_RE.fullmatch(value) if isinstance(value, str) else None
    if not match:
        raise _invalid('observed_at must be a UTC timestamp ending in Z.')
    try:
        moment = datetime.strptime(match[1], '%Y-%m-%dT%H:%M:%S').replace(tzinfo=timezone.utc)
    except ValueError:
        raise _invalid('observed_at is not a valid calendar time.') from None
    return _instant(moment, match[2] or '')


_last_stamp = [datetime.min.replace(tzinfo=timezone.utc)]
_stamp_lock = threading.Lock()


def _utc_now_text():
    """Strictly increasing microsecond UTC-Z time, so distinct captures never produce identical records."""
    with _stamp_lock:
        moment = max(datetime.now(timezone.utc), _last_stamp[0] + timedelta(microseconds=1))
        _last_stamp[0] = moment
    return moment.strftime('%Y-%m-%dT%H:%M:%S.%fZ')


def validate_observation_record(record):
    """Record syntax and consistency only; never native provenance."""
    if not isinstance(record, dict) or set(record) != OBSERVATION_FIELDS:
        raise _invalid('Observation must contain exactly the model-observation/v1 fields.')
    checks = (
        (record['schema'] == OBSERVATION_SCHEMA and isinstance(record['schema'], str), 'schema'),
        (_member(record['host'], HOSTS), 'host'),
        (isinstance(record['cli_version'], str) and VERSION_RE.fullmatch(record['cli_version']), 'cli_version'),
        (isinstance(record['scope_id'], str) and ID_RE.fullmatch(record['scope_id']), 'scope_id'),
        (_member(record['scope_kind'], SCOPE_KINDS), 'scope_kind'),
        (_member(record['purpose'], PURPOSES), 'purpose'),
        (_member(record['source'], SOURCES), 'source'),
        (_member(record['status'], STATUSES), 'status'),
        (_text(record['reason']), 'reason'),
        (isinstance(record['models'], list), 'models'),
    )
    for ok, field in checks:
        if not ok:
            raise _invalid('Observation field ' + field + ' is invalid.')
    _parse_utc(record['observed_at'])
    seen = set()
    for model in record['models']:
        if not isinstance(model, dict) or set(model) != MODEL_FIELDS:
            raise _invalid('Each observed model must contain exactly native_id, efforts and available.')
        native_id, efforts = model['native_id'], model['efforts']
        if not isinstance(native_id, str) or not ID_RE.fullmatch(native_id) or native_id in seen:
            raise _invalid('Observed native_id values must be valid and unique.')
        seen.add(native_id)
        if (not isinstance(efforts, list) or not all(_member(e, EFFORTS) for e in efforts)
                or len(set(efforts)) != len(efforts)):
            raise _invalid('Observed efforts must be unique low/medium/high/xhigh values.')
        if type(model['available']) is not bool:
            raise _invalid('Observed available must be a boolean.')
    if record['source'] == 'unsupported' and record['status'] != 'unavailable':
        raise _invalid('Unsupported discovery must be unavailable.')
    if record['status'] == 'unavailable' and record['models']:
        raise _invalid('Unavailable observations cannot list models.')
    sha = record['observation_sha256']
    if not isinstance(sha, str) or not SHA_RE.fullmatch(sha) or sha != observation_digest(record):
        raise _invalid('observation_sha256 does not match the canonical record.')


def validate_error_record(record):
    if not isinstance(record, dict) or set(record) != ERROR_FIELDS or record['schema'] != ERROR_SCHEMA:
        raise _invalid('Error must contain exactly the model-policy-error/v1 fields.')
    if not isinstance(record['schema'], str) or not _member(record['reason'], REASONS) or not _text(record['message']):
        raise _invalid('Error reason or message is invalid.')


def _check_fresh(record, now, max_age_seconds):
    if type(max_age_seconds) is not int or max_age_seconds <= 0:
        raise _invalid('max_age_seconds must be a positive integer.')
    if now is None:
        now = datetime.now(timezone.utc)
    if not isinstance(now, datetime) or now.utcoffset() != timedelta(0):
        raise _invalid('now must be a timezone-aware UTC datetime.')
    seconds, fraction = _parse_utc(record['observed_at'])
    current = _instant(now.replace(microsecond=0), '%06d' % now.microsecond)
    if (seconds, fraction) > current or (seconds + max_age_seconds, fraction) < current:
        raise PolicyError('discovery-stale', 'Observation is stale or from the future; rerun discovery.')


def validate_configuration(record, *, now=None, max_age_seconds=300):
    """Validate a verified-configuration record; never native discovery or access proof."""
    validate_observation_record(record)
    if record['source'] != 'verified-configuration':
        raise _invalid('Configuration observations must use source verified-configuration.')
    _check_fresh(record, now, max_age_seconds)


def validate_observation(record, *, capture, purpose, require_live=True, now=None, max_age_seconds=300):
    """Validate a record against the private witness of the genuine native capture that produced it."""
    if not _member(purpose, PURPOSES):
        raise _invalid('purpose must be diagnostic or launch.')
    if not isinstance(capture, Capture):
        raise _invalid('A genuine native capture is required.')
    validate_observation_record(record)
    if canonical(record) != capture._canonical or record['observation_sha256'] != capture._digest:
        raise PolicyError('scope-mismatch', 'Observation was not produced by this native capture.')
    if record['purpose'] != purpose or capture._purpose != purpose:
        raise PolicyError('scope-mismatch', 'Observation purpose does not match the consumer; capture a new one.')
    if record['source'] != 'live-discovery' or record['status'] != 'complete':
        raise PolicyError('discovery-incomplete', 'Live consumption requires a complete live discovery.')
    _check_fresh(record, now, max_age_seconds)
    capture._client._check_active()  # always local; require_live only adds the native context refresh
    if require_live and capture._client._current_context() != capture._context:
        raise PolicyError('scope-mismatch', 'Native client context changed; rerun discovery.')


class Capture:
    """Normalized observation plus a private in-process witness of its originating native capture."""
    __slots__ = ('observation', '_client', '_context', '_purpose', '_canonical', '_digest')

    def __init__(self, observation, client, context, purpose):
        self.observation = observation
        self._client = client
        self._context = context
        self._purpose = purpose
        self._canonical = canonical(observation)
        self._digest = observation['observation_sha256']

    def __repr__(self):
        return '<Capture purpose=%s sha256=%s>' % (self._purpose, self._digest[:12])


class _TransportFailure(Exception):
    """Native exchange failed; carries no native text."""


class _RpcError(Exception):
    """Native server answered with an error object; its text is never surfaced."""


class _Discovery(Exception):
    def __init__(self, reason, message, status):
        super().__init__(message)
        self.reason, self.message, self.status = reason, message, status


def _bounded(action, timeout):
    """Run a possibly blocking pipe call on a daemon thread; return True only if it finished without error.

    Portable (no select() on Windows anonymous pipes): the caller never waits past timeout, and owners
    terminate the child, which breaks the pipe and releases the thread.
    """
    failed = []

    def run():
        try:
            action()
        except (OSError, ValueError, AttributeError):
            failed.append(True)

    worker = threading.Thread(target=run, name='codex-app-server-writer', daemon=True)
    worker.start()
    worker.join(timeout=max(timeout, 0))
    return not worker.is_alive() and not failed


def _terminate(process):
    """Terminate and reap an owned child with bounded waits; kill if terminate is ignored."""
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=CLEANUP_WAIT_SECONDS)
        except subprocess.TimeoutExpired:
            process.kill()
            try:
                process.wait(timeout=CLEANUP_WAIT_SECONDS)
            except subprocess.TimeoutExpired:
                pass


def _read_version(executable):
    """Actual `codex --version` stdout, read incrementally and capped at MAX_VERSION_BYTES before decoding.

    Returns '' on overflow, timeout, nonzero exit or spawn failure; the owned child is always reaped.
    """
    deadline = time.monotonic() + VERSION_TIMEOUT_SECONDS
    try:
        process = subprocess.Popen([executable, '--version'], stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                   stderr=subprocess.DEVNULL)
    except (OSError, ValueError, subprocess.SubprocessError):
        return ''
    stdout = process.stdout
    if stdout is None:
        _terminate(process)
        return ''
    captured, drained = bytearray(), threading.Event()

    def read():
        try:
            descriptor = stdout.fileno()
            while len(captured) <= MAX_VERSION_BYTES:
                chunk = os.read(descriptor, MAX_VERSION_BYTES + 1 - len(captured))  # never more than the cap
                if not chunk:
                    return
                captured.extend(chunk)
        finally:
            drained.set()

    try:
        if not _bounded(read, deadline - time.monotonic()) or len(captured) > MAX_VERSION_BYTES:
            return ''
        try:
            if process.wait(timeout=max(deadline - time.monotonic(), 0)) != 0:
                return ''
        except subprocess.TimeoutExpired:
            return ''
        return bytes(captured).decode('ascii').strip()
    except UnicodeDecodeError:
        return ''
    finally:
        _terminate(process)
        # Reaping breaks the pipe and releases the reader; close only once it no longer uses the descriptor.
        if drained.wait(CLEANUP_WAIT_SECONDS):
            stdout.close()


def _seal(record):
    return {**record, 'observation_sha256': observation_digest(record)}


def unavailable_observation(host, source, scope_id, reason, cli_version=UNAVAILABLE_VERSION):
    return _seal({'schema': OBSERVATION_SCHEMA, 'host': host, 'cli_version': cli_version, 'scope_id': scope_id,
                  'scope_kind': 'client', 'purpose': 'diagnostic', 'observed_at': _utc_now_text(), 'source': source,
                  'status': 'unavailable', 'models': [], 'reason': reason})


def _fresh_client_scope():
    return 'client-' + os.urandom(16).hex()


def _schema_object(value, required):
    """Required native DTO fields with their generated-schema types (only fields this helper relies on)."""
    return isinstance(value, dict) and all(
        key in value and (type(value[key]) is bool if kind is bool else isinstance(value[key], kind))
        for key, kind in required.items())


INIT_REQUIRED = {'codexHome': str, 'platformFamily': str, 'platformOs': str, 'userAgent': str}
MODEL_REQUIRED = {'id': str, 'model': str, 'displayName': str, 'description': str, 'hidden': bool,
                  'isDefault': bool, 'defaultReasoningEffort': str, 'supportedReasoningEfforts': list}
EFFORT_REQUIRED = {'reasoningEffort': str, 'description': str}
ACCOUNT_REQUIRED = {'apiKey': {}, 'chatgpt': {'planType': str}, 'amazonBedrock': {}}
ROUTING_REQUIRED = {'accountRoutingOverride': str, 'backendOrigin': str, 'chatgptAccountId': str}
# Closed enums from the pinned generated Codex 0.159.2 GetAccountResponse schema.
PLAN_TYPES = ('free', 'go', 'plus', 'pro', 'prolite', 'promax', 'team', 'self_serve_business_prolite',
              'self_serve_business_usage_based', 'business', 'ent26', 'enterprise_cbp_automation',
              'enterprise_cbp_usage_based', 'enterprise', 'edu', 'edu_plus', 'edu_pro', 'unknown')
ROUTING_OVERRIDES = ('NO_CONSTRAINT', 'us', 'us_cr')


def _account_context(result):
    """Documented GetAccountResponse fields only; held in memory and bound by keyed hash, never persisted."""
    if not _schema_object(result, {'requiresOpenaiAuth': bool}):
        raise _TransportFailure()
    account, routing = result.get('account'), result.get('workspaceRouting')
    if account is not None:
        kind = account.get('type') if isinstance(account, dict) else None
        if not isinstance(kind, str) or kind not in ACCOUNT_REQUIRED or not _schema_object(account, ACCOUNT_REQUIRED[kind]):
            raise _TransportFailure()
        if kind == 'chatgpt' and ('email' not in account or not isinstance(account['email'], (str, type(None)))
                                  or not _member(account['planType'], PLAN_TYPES)):
            raise _TransportFailure()
    if routing is not None and (not _schema_object(routing, ROUTING_REQUIRED)
                                or not _member(routing['accountRoutingOverride'], ROUTING_OVERRIDES)):
        raise _TransportFailure()
    return {'requiresOpenaiAuth': result['requiresOpenaiAuth'], 'account': account, 'workspaceRouting': routing}


def _normalize_page(result, source_ids, native_ids):
    """Validate one ModelListResponse page; return normalized models and the raw nextCursor value."""
    if not isinstance(result, dict) or not isinstance(result.get('data'), list):
        raise _TransportFailure()
    models = []
    for item in result['data']:
        if not _schema_object(item, MODEL_REQUIRED) or not item['defaultReasoningEffort']:
            raise _TransportFailure()
        efforts = set()
        for option in item['supportedReasoningEfforts']:
            if not _schema_object(option, EFFORT_REQUIRED) or not option['reasoningEffort']:
                raise _TransportFailure()
            efforts.add(option['reasoningEffort'])
        native_id = item['model']
        if not ID_RE.fullmatch(native_id) or item['id'] in source_ids or native_id in native_ids:
            raise _TransportFailure()
        source_ids.add(item['id'])
        native_ids.add(native_id)
        models.append({'native_id': native_id, 'efforts': [e for e in EFFORTS if e in efforts], 'available': True})
    return models, result.get('nextCursor')


class CodexClient:
    """One owned `codex app-server` child speaking documented JSON-lines JSON-RPC; read-only discovery."""

    def __init__(self, scope_namespace):
        if not isinstance(scope_namespace, str) or not ID_RE.fullmatch(scope_namespace):
            raise _invalid('scope namespace must be a short nonsecret identifier.')
        self._namespace = scope_namespace
        self._nonce = os.urandom(32)
        self._process = None
        self._lines = None
        self._stop = threading.Event()
        self._reader = None
        self._next_id = 0
        self._version = None
        self._init_context = None
        self._failed = False
        self._closed = False
        self._deadline = 0.0
        self._budget = 0

    def __enter__(self):
        return self

    def __exit__(self, *_exc):
        self.close()

    def __repr__(self):
        return '<CodexClient>'

    def close(self):
        self._closed = True
        self._stop_process()

    def _stop_process(self):
        process, self._process = self._process, None
        if process is None:
            return
        self._stop.set()
        # Terminate and reap first: a buffered stdin close may block on a full pipe or a stuck writer thread.
        _terminate(process)
        _bounded(process.stdin.close, CLEANUP_WAIT_SECONDS)
        if self._reader is not None:
            self._reader.join(timeout=CLEANUP_WAIT_SECONDS)
            if not self._reader.is_alive():
                process.stdout.close()

    def _begin_operation(self):
        self._deadline = time.monotonic() + OPERATION_TIMEOUT_SECONDS
        self._budget = MAX_OPERATION_BYTES

    def _read_loop(self, stream, lines):
        # Portable bounded pipe reading: no select() on anonymous pipes (unsupported on Windows).
        while not self._stop.is_set():
            try:
                line = stream.readline(MAX_LINE_BYTES + 1)
            except (OSError, ValueError):
                line = b''
            if len(line) > MAX_LINE_BYTES:
                line = None  # oversize line: stop reading this stream
            while not self._stop.is_set():
                try:
                    lines.put(line, timeout=0.5)
                    break
                except queue.Full:
                    continue
            if not line:
                return

    def _start(self):
        executable = shutil.which('codex')
        if executable is None:
            raise _Discovery('discovery-unavailable', 'Codex CLI was not found on PATH; install or expose codex.',
                             'unavailable')
        version = _read_version(executable)
        if not VERSION_RE.fullmatch(version):
            raise _Discovery('discovery-unavailable', 'Codex CLI version could not be read; check the installation.',
                             'unavailable')
        self._version = version
        try:
            self._process = subprocess.Popen([executable, 'app-server'], stdin=subprocess.PIPE,
                                             stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
        except (OSError, ValueError):
            raise _Discovery('discovery-unavailable', 'Codex app-server could not be started.', 'unavailable') from None
        self._lines = queue.Queue(maxsize=4)
        self._reader = threading.Thread(target=self._read_loop, args=(self._process.stdout, self._lines),
                                        name='codex-app-server-reader', daemon=True)
        self._reader.start()
        try:
            result = self._request('initialize', {'clientInfo': dict(CLIENT_INFO)})
            if not _schema_object(result, INIT_REQUIRED):
                raise _TransportFailure()
            self._send({'method': 'initialized', 'params': {}})
        except (_TransportFailure, _RpcError):
            raise _Discovery('discovery-unavailable', 'Codex app-server initialization failed; rerun discovery.',
                             'unavailable') from None
        self._init_context = {k: result[k] for k in INIT_REQUIRED}

    def _send(self, message):
        stream, data = getattr(self._process, 'stdin', None), canonical(message) + b'\n'
        if stream is None:
            raise _TransportFailure()

        def write():
            stream.write(data)
            stream.flush()

        deadline = min(self._deadline, time.monotonic() + REQUEST_TIMEOUT_SECONDS)
        if not _bounded(write, deadline - time.monotonic()):
            raise _TransportFailure()

    def _receive(self, deadline):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise _TransportFailure()
        lines = self._lines
        if lines is None:
            raise _TransportFailure()
        try:
            line = lines.get(timeout=remaining)
        except queue.Empty:
            raise _TransportFailure() from None
        if not line:
            raise _TransportFailure()  # EOF or oversize line
        self._budget -= len(line)
        if self._budget < 0:
            raise _TransportFailure()
        try:
            return strict_json(line)
        except PolicyError:
            raise _TransportFailure() from None

    def _request(self, method, params):
        """Private seam: one correlated JSON-RPC request; returns its result object."""
        if self._process is None:
            raise _TransportFailure()
        request_id = self._next_id
        self._next_id += 1
        try:
            self._send({'id': request_id, 'method': method, 'params': params})
            deadline = min(self._deadline, time.monotonic() + REQUEST_TIMEOUT_SECONDS)
            while True:
                message = self._receive(deadline)
                if 'method' in message:
                    continue  # notifications and server requests are not part of discovery
                if type(message.get('id')) is not int or message['id'] != request_id:
                    raise _TransportFailure()
                if message.pop('jsonrpc', '2.0') != '2.0':  # documented wire omits it; tolerate the standard value
                    raise _TransportFailure()
                if set(message) == {'id', 'error'}:
                    raise _RpcError()
                if set(message) != {'id', 'result'} or not isinstance(message['result'], dict):
                    raise _TransportFailure()
                return message['result']
        except _TransportFailure:
            self._failed = True  # stream state is unknown; never reuse this child
            self._stop_process()
            raise

    def _read_context(self):
        """Obtainable documented context (init + account/read refreshToken=false) as (account_read, keyed digest)."""
        try:
            account = _account_context(self._request('account/read', {'refreshToken': False}))
        except _RpcError:
            account = None  # account metadata unsupported or unavailable: honest client-only context
        data = canonical({'cli_version': self._version, 'init': self._init_context, 'account': account})
        return account is not None, hmac.new(self._nonce, data, hashlib.sha256).hexdigest()

    def _check_active(self):
        """Local originating-client state: open, not failed, owned child still running."""
        if self._closed or self._failed or self._process is None:
            raise PolicyError('discovery-unavailable', 'Originating Codex client is closed; rerun discovery.')
        if self._process.poll() is not None:
            self._failed = True
            self._stop_process()
            raise PolicyError('discovery-unavailable', 'Originating Codex app-server exited; rerun discovery.')

    def _current_context(self):
        """Live-consumption recheck on the originating client."""
        self._check_active()
        self._begin_operation()
        try:
            return self._read_context()
        except _TransportFailure:
            raise PolicyError('discovery-unavailable', 'Codex account context could not be read.') from None

    def _scope(self, context):
        material = canonical({'namespace': self._namespace, 'context': context[1] if context else None})
        return 'client-' + hmac.new(self._nonce, material, hashlib.sha256).hexdigest()[:32]

    def capture(self, *, purpose='diagnostic'):
        if not _member(purpose, PURPOSES):
            raise _invalid('purpose must be diagnostic or launch.')
        if self._closed:
            raise PolicyError('discovery-unavailable', 'Codex client is closed; open a new client.')
        observed_at = _utc_now_text()
        context = None
        models: list[dict] = []

        def observation(status, reason):
            return _seal({'schema': OBSERVATION_SCHEMA, 'host': 'codex-cli',
                          'cli_version': self._version or UNAVAILABLE_VERSION, 'scope_id': self._scope(context),
                          'scope_kind': 'client', 'purpose': purpose, 'observed_at': observed_at,
                          'source': 'live-discovery', 'status': status, 'models': models if status != 'unavailable'
                          else [], 'reason': reason})

        try:
            if self._failed:
                raise _Discovery('discovery-unavailable', 'Codex client failed earlier; open a new client.',
                                 'unavailable')
            self._begin_operation()
            if self._process is None:
                try:
                    self._start()
                except _Discovery:
                    self._failed = True
                    self._stop_process()
                    raise
            context = self._capture_context('unavailable')
            pages = self._list_models(models)
            if self._capture_context('incomplete') != context:
                raise _Discovery('scope-mismatch', 'Codex account or provider context changed during discovery.',
                                 'incomplete')
        except _Discovery as failure:
            raise PolicyError(failure.reason, failure.message,
                              observation=observation(failure.status, failure.message)) from None
        account = 'was read' if context[0] else 'was unavailable'
        reason = ('All %d documented model/list page(s) were read with includeHidden=true; account metadata %s. '
                  'Scope is a fresh client scope, not account attestation; listing does not prove inference access.'
                  % (pages, account))
        return Capture(observation('complete', reason), self, context, purpose)

    def _capture_context(self, status):
        try:
            return self._read_context()
        except _TransportFailure:
            reason = 'discovery-unavailable' if status == 'unavailable' else 'discovery-incomplete'
            raise _Discovery(reason, 'Codex account context could not be read; rerun discovery.', status) from None

    def _list_models(self, models):
        """Read every model/list page into models; return the page count or raise _Discovery."""
        source_ids: set[str] = set()
        native_ids: set[str] = set()
        cursors, cursor, pages = set(), None, 0
        while True:
            def failed():
                if pages:
                    return _Discovery('discovery-incomplete', 'Codex model/list pagination did not complete; '
                                      'rerun discovery.', 'incomplete')
                return _Discovery('discovery-unavailable', 'Codex model/list returned no usable page; '
                                  'rerun discovery.', 'unavailable')

            if pages >= MAX_PAGES:
                raise failed()
            params = {'includeHidden': True} if cursor is None else {'includeHidden': True, 'cursor': cursor}
            try:
                page, cursor = _normalize_page(self._request('model/list', params), source_ids, native_ids)
            except (_TransportFailure, _RpcError):
                raise failed() from None
            models.extend(page)
            pages += 1
            if cursor is None:
                return pages
            if not isinstance(cursor, str) or not cursor or len(cursor) > MAX_CURSOR_CHARS or cursor in cursors:
                raise failed()
            cursors.add(cursor)


# ---- CLI -------------------------------------------------------------------------------------------------

DISCOVER_OPTIONS = ('--host', '--scope-id', '--output')


def _parse_discover(argv):
    if not argv or argv[0] != 'discover':
        raise _invalid('Usage: model-policy.py discover --host HOST --scope-id ID --output FILE.')
    options, rest = {}, argv[1:]
    while rest:
        if len(rest) < 2 or rest[0] not in DISCOVER_OPTIONS or rest[0] in options:
            raise _invalid('Unknown, duplicate or incomplete discover argument.')
        options[rest[0]] = rest[1]
        rest = rest[2:]
    if set(options) != set(DISCOVER_OPTIONS):
        raise _invalid('discover requires --host, --scope-id and --output exactly once.')
    if not _member(options['--host'], HOSTS):
        raise _invalid('--host must be one of claude-code, codex-cli, copilot-cli, gemini-cli.')
    if not ID_RE.fullmatch(options['--scope-id']):
        raise _invalid('--scope-id must be a short nonsecret identifier.')
    return options['--host'], options['--scope-id'], _output_path(options['--output'])


def _output_path(text):
    """Contained relative output path under the working directory; no traversal, symlink or directory target."""
    if (not text or text.startswith(('/', '\\')) or re.match(r'^[A-Za-z]:', text) or '\\' in text
            or any(ord(c) < 32 or ord(c) == 127 for c in text)
            or any(part in ('', '.', '..') for part in text.split('/'))):
        raise _invalid('--output must be a relative file path inside the working directory.')
    base = Path.cwd().resolve()
    target = base.joinpath(*text.split('/'))
    try:
        parent = target.parent.resolve(strict=True)
    except (OSError, RuntimeError):
        raise _invalid('--output directory does not exist inside the working directory.') from None
    if (parent != base and base not in parent.parents) or not parent.is_dir():
        raise _invalid('--output must stay inside the working directory.')
    target = parent / target.name
    if target.is_symlink() or (target.exists() and not target.is_file()):
        raise _invalid('--output must name a regular file.')
    return target


def _write(target, record):
    handle, temp = tempfile.mkstemp(prefix='.model-observation-', dir=str(target.parent))
    try:
        with os.fdopen(handle, 'wb') as stream:
            stream.write(canonical(record))
        os.replace(temp, str(target))
    except OSError:
        try:
            os.unlink(temp)
        except OSError:
            pass
        raise PolicyError('input-invalid', 'Could not write --output; check the path and permissions.') from None


def _discover(host, namespace, target):
    if host != 'codex-cli':
        message = ('Native model discovery is not documented for ' + host + '; use verified configuration '
                   'or an explicit eligible pin.')
        _write(target, unavailable_observation(host, 'unsupported', _fresh_client_scope(), message))
        raise PolicyError('discovery-unavailable', message)
    with CodexClient(namespace) as client:
        try:
            result = client.capture(purpose='diagnostic')
        except PolicyError as error:
            if error.observation is not None:
                _write(target, error.observation)
            raise
    _write(target, result.observation)


def main(argv):
    try:
        _discover(*_parse_discover(argv))
        return 0
    except PolicyError as failure:
        error = failure
    except Exception:  # closed envelope only; never a traceback or raw native text
        error = PolicyError('discovery-unavailable', 'Discovery failed unexpectedly; rerun discover.')
    sys.stderr.buffer.write(canonical(error.as_dict()) + b'\n')
    sys.stderr.flush()
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
