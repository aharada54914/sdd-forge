#!/usr/bin/env python3
"""Documented discovery, immutable selection binding and scoped delivery validation (T-004/T-005).

Standard library only. Discovery never starts a thread/turn, never logs in or refreshes credentials,
and never persists raw native prose, account data or paths. Model choice and native launch remain downstream.
"""
from collections.abc import Mapping
import contextvars
from datetime import datetime, timedelta, timezone
import copy
import math
from urllib.parse import urlsplit
import hashlib
import hmac
import json
import os
from pathlib import Path
import queue
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import threading
import time
from types import MappingProxyType

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
_HTTPS_METADATA_RE = re.compile(
    r'^[Hh][Tt][Tt][Pp][Ss]://(?:[^\s/?#@:\[\]]+|\[[^\]\s]+\])(?::[0-9]*)?(?:[/?#][^\s]*)?(?![\s\S])'
)
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

# Private launch-controls scope (T-007): a captured snapshot root and environment. Unset means legacy behavior.
_SNAPSHOT_ROOT: 'contextvars.ContextVar[Path | None]' = contextvars.ContextVar('model_policy_snapshot_root',
                                                                               default=None)
_CAPTURED_ENVIRONMENT: 'contextvars.ContextVar[Mapping[str, str] | None]' = contextvars.ContextVar(
    'model_policy_captured_environment', default=None)


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


# ---- Immutable selection and delivery (T-005) --------------------------------------------------------------

SELECTION_SCHEMA = 'model-selection/v1'
DELIVERY_SCHEMA = 'model-delivery/v1'
POLICIES = ('latest-compatible', 'pinned')
PROVENANCE = ('cli', 'environment', 'project-role', 'project-default', 'shipped')
SELECTION_FIELDS = frozenset(('schema', 'role', 'risk', 'host', 'cli_version', 'scope_id', 'requested',
                             'resolved', 'policy_sha256', 'catalog_sha256', 'observation_sha256', 'observed_at',
                             'source_date', 'reason', 'update_candidates', 'binding', 'budget', 'estimate',
                             'selection_sha256'))
DELIVERY_FIELDS = frozenset(('schema', 'selection_sha256', 'run_id', 'session_id', 'turn_id', 'configured_id',
                            'actual_id', 'proof', 'source', 'reroutes', 'status', 'reason'))
EVENT_FIELDS = frozenset(('host', 'cli_version', 'selection_sha256', 'run_id', 'session_id', 'thread_id',
                         'turn_id', 'thread_read', 'turn_start', 'notifications'))
BINDING_FIELDS = ('run_id', 'session_id', 'attempt')
REROUTE_FIELDS = ('thread_id', 'turn_id', 'from_model', 'to_model', 'reason')


def _fields(value, fields, label):
    if not isinstance(value, dict) or set(value) != set(fields):
        raise _invalid(label + ' must contain exactly its declared fields.')


def _id(value):
    return isinstance(value, str) and ID_RE.fullmatch(value) is not None


def _hash(value):
    return isinstance(value, str) and SHA_RE.fullmatch(value) is not None


def _binding(value):
    _fields(value, BINDING_FIELDS, 'Binding')
    if (not _id(value['run_id']) or not _id(value['session_id'])
            or type(value['attempt']) is not int or value['attempt'] <= 0):
        raise _invalid('Binding requires valid run/session identifiers and a positive integer attempt.')


def selection_digest(record):
    return hashlib.sha256(canonical({k: v for k, v in record.items() if k != 'selection_sha256'})).hexdigest()


def validate_selection_record(record, *, require_bound=False):
    """Syntax and immutable-record consistency only; not model eligibility or native availability proof."""
    _fields(record, SELECTION_FIELDS, 'Selection')
    if type(require_bound) is not bool:
        raise _invalid('require_bound must be boolean.')
    if (record['schema'] != SELECTION_SCHEMA or not _id(record['role'])
            or not _member(record['risk'], ('low', 'medium', 'high', 'critical'))
            or not _member(record['host'], HOSTS) or not _id(record['scope_id'])
            or not isinstance(record['cli_version'], str) or not VERSION_RE.fullmatch(record['cli_version'])
            or not _text(record['reason'])):
        raise _invalid('Selection metadata is invalid.')
    requested, resolved = record['requested'], record['resolved']
    _fields(requested, ('policy', 'model_id', 'policy_source', 'model_source'), 'Requested selection')
    _fields(resolved, ('catalog_id', 'native_id', 'effort', 'effort_control'), 'Resolved selection')
    if (not _member(requested['policy'], POLICIES) or not _member(requested['policy_source'], PROVENANCE)
            or requested['model_id'] is not None and not _id(requested['model_id'])
            or requested['model_source'] is not None and not _member(requested['model_source'], PROVENANCE)):
        raise _invalid('Requested configuration is invalid.')
    pinned = requested['policy'] == 'pinned'
    if pinned != (requested['model_id'] is not None) or pinned != (requested['model_source'] is not None):
        raise PolicyError('config-conflict', 'Pinned selection requires an explicit ID and source; latest must omit them.')
    if (not _id(resolved['catalog_id']) or not _id(resolved['native_id'])
            or not _member(resolved['effort'], EFFORTS) or not _text(resolved['effort_control'])):
        raise _invalid('Resolved model or effort is invalid.')
    for field in ('policy_sha256', 'catalog_sha256', 'observation_sha256', 'selection_sha256'):
        if not _hash(record[field]):
            raise _invalid('Selection digest field is invalid.')
    for field in ('observed_at', 'source_date'):
        _parse_utc(record[field])
    candidates = record['update_candidates']
    if (not isinstance(candidates, list) or not all(_id(item) for item in candidates)
            or len(set(candidates)) != len(candidates)):
        raise _invalid('Update candidates must be unique valid identifiers.')
    if record['binding'] is not None:
        _binding(record['binding'])
    elif require_bound:
        raise _invalid('A bound selection is required.')
    budget, estimate = record['budget'], record['estimate']
    for value, fields in ((budget, ('amount', 'unit')),
                          (estimate, ('catalog_id', 'amount', 'unit', 'source_url', 'source_date'))):
        if value is None:
            continue
        _fields(value, fields, 'Monetary evidence')
        amount = value['amount']
        if (type(amount) not in (int, float) or amount < 0
                or type(amount) is float and not math.isfinite(amount) or value['unit'] != 'USD'):
            raise _invalid('Monetary evidence requires a finite nonnegative USD amount.')
    if estimate is not None:
        if not _id(estimate['catalog_id']) or not _https_metadata(estimate['source_url']):
            raise _invalid('Estimate source or catalog identifier is invalid.')
        _parse_utc(estimate['source_date'])
        if estimate['catalog_id'] != resolved['catalog_id']:
            raise PolicyError('budget-unverifiable', 'Estimate is for a different selected catalog model.')
    if budget is not None and (estimate is None or estimate['amount'] > budget['amount']):
        raise PolicyError('budget-unverifiable', 'A compatible estimate within the configured budget is required.')
    if record['selection_sha256'] != selection_digest(record):
        raise _invalid('selection_sha256 does not match the canonical record.')


def _https_metadata(value):
    if not isinstance(value, str) or not 1 <= len(value) <= 2048 or not _HTTPS_METADATA_RE.fullmatch(value):
        return False
    try:
        parsed = urlsplit(value)
        parsed.port  # Access performs urllib's numeric and range validation.
        return (parsed.scheme == 'https' and bool(parsed.hostname)
                and parsed.username is None and parsed.password is None)
    except ValueError:
        return False


def bind_selection(record, *, run_id, session_id, attempt):
    validate_selection_record(record)
    binding = {'run_id': run_id, 'session_id': session_id, 'attempt': attempt}
    _binding(binding)
    if record['binding'] is not None and record['binding'] != binding:
        raise PolicyError('resume-conflict', 'The selection is already bound to another run, session or attempt.')
    result = copy.deepcopy(record)
    result['binding'] = binding
    result['selection_sha256'] = selection_digest(result)
    return result


def validate_resume_selection(original, candidate):
    validate_selection_record(original, require_bound=True)
    validate_selection_record(candidate)
    for field in SELECTION_FIELDS - {'selection_sha256', 'binding'}:
        if canonical(original[field]) != canonical(candidate[field]):
            raise PolicyError('resume-conflict', 'Resume must retain every original selection field; start a new attempt.')
    if candidate['binding'] is not None and candidate['binding'] != original['binding']:
        raise PolicyError('resume-conflict', 'Resume binding differs; start a new attempt.')


def _native_turn(value):
    if (not _schema_object(value, {'id': str, 'items': list, 'status': str}) or not _id(value['id'])
            or value['status'] not in ('completed', 'interrupted', 'failed', 'inProgress')):
        raise _invalid('Native turn metadata is malformed.')


def _codex_reroutes(selection, events):
    """Read admitted native DTO fields only. Neither configuration nor reroute target attests execution ID."""
    read, start = events['thread_read'], events['turn_start']
    if not _schema_object(read, {'thread': dict}) or not _schema_object(start, {'turn': dict}):
        raise _invalid('Codex thread/read and turn/start response objects are required.')
    thread, turn = read['thread'], start['turn']
    required = {'cliVersion': str, 'createdAt': int, 'cwd': str, 'ephemeral': bool, 'id': str,
                'modelProvider': str, 'preview': str, 'sessionId': str, 'source': (str, dict),
                'status': dict, 'turns': list, 'updatedAt': int}
    if (not _schema_object(thread, required) or 'projectId' not in thread
            or not isinstance(thread['projectId'], (str, type(None)))
            or type(thread['createdAt']) is not int or type(thread['updatedAt']) is not int
            or not _id(thread['id']) or not _id(thread['sessionId']) or not _text(thread['cliVersion'], 128)):
        raise _invalid('Native thread metadata is malformed.')
    _native_turn(turn)
    if (thread['id'] != events['thread_id'] or thread['sessionId'] != events['session_id']
            or turn['id'] != events['turn_id']):
        raise PolicyError('scope-mismatch', 'Native thread, session or turn does not match this delivery.')
    configured = thread.get('model')
    if configured is not None:
        if not _id(configured):
            raise _invalid('Native configured model is malformed.')
        if configured != selection['resolved']['native_id']:
            raise PolicyError('native-precedence-conflict', 'Native configured model differs from the selection.')
    effort = thread.get('reasoningEffort')
    if effort is not None:
        if not isinstance(effort, str) or not effort:
            raise _invalid('Native configured effort is malformed.')
        if effort != selection['resolved']['effort']:
            raise PolicyError('config-conflict', 'Native configured effort differs from the selection.')
    rows, seen = [], set()
    previous = selection['resolved']['native_id']
    for event in events['notifications']:
        if not isinstance(event, dict) or not isinstance(event.get('method'), str):
            raise _invalid('Native notification is malformed.')
        method, params = event['method'], event.get('params')
        if method not in ('model/rerouted', 'turn/completed'):
            continue  # Unrelated documented notifications and their text never become identity evidence.
        if not isinstance(params, dict) or not _id(params.get('threadId')):
            raise _invalid('Native notification scope is malformed.')
        if method == 'turn/completed':
            if params['threadId'] != events['thread_id']:
                continue
            _native_turn(params.get('turn'))
            continue  # Completion status does not attest a model, including other turns of this thread.
        if not _id(params.get('turnId')):
            raise _invalid('Native reroute turn is malformed.')
        if params['threadId'] != events['thread_id'] or params['turnId'] != events['turn_id']:
            continue
        if (not _id(params.get('fromModel')) or not _id(params.get('toModel'))
                or params.get('reason') != 'highRiskCyberActivity'):
            raise _invalid('Matching native reroute metadata is malformed.')
        row = dict(zip(REROUTE_FIELDS, (params['threadId'], params['turnId'], params['fromModel'],
                                       params['toModel'], params['reason'])))
        key = canonical(row)
        if key in seen or params['fromModel'] != previous:
            raise _invalid('Matching native reroutes are duplicated or have a contradictory chain.')
        seen.add(key)
        rows.append(row)
        previous = params['toModel']
    return rows


def verify_delivery(selection, events, *, require_actual_id, transport=None):
    validate_selection_record(selection, require_bound=True)
    if transport is not None and (not isinstance(transport, str) or transport != 'codex-exec'):
        raise _invalid('Delivery transport must be absent or the trusted codex-exec context.')
    if type(require_actual_id) is not bool:
        raise _invalid('require_actual_id must be boolean and come from the consuming contract.')
    _fields(events, EVENT_FIELDS, 'Captured events')
    if (not _member(events['host'], HOSTS) or not isinstance(events['cli_version'], str)
            or not VERSION_RE.fullmatch(events['cli_version']) or not _hash(events['selection_sha256'])
            or not all(_id(events[field]) for field in ('run_id', 'session_id', 'thread_id', 'turn_id'))
            or not isinstance(events['notifications'], list)):
        raise _invalid('Captured event metadata is invalid.')
    binding = selection['binding']
    expected = {key: selection[key] for key in ('host', 'cli_version', 'selection_sha256')}
    expected.update(run_id=binding['run_id'], session_id=binding['session_id'])
    if any(events[key] != value for key, value in expected.items()):
        raise PolicyError('scope-mismatch', 'Captured events do not belong to this bound selection.')
    if transport == 'codex-exec':
        # Only the actual exec launcher supplies this context. A delivery DTO's
        # source field cannot select a weaker native-evidence interpretation.
        if (selection['host'] != 'codex-cli' or events['thread_read'] is not None
                or events['turn_start'] is not None or events['notifications']):
            raise _invalid('Codex exec requires matching Codex context and no app-server identity DTOs.')
        rows, source = [], 'codex-exec'
    elif selection['host'] == 'codex-cli':
        rows = _codex_reroutes(selection, events)
        source = 'codex-app-server'
    else:
        if events['thread_read'] is not None or events['turn_start'] is not None or events['notifications']:
            raise _invalid('This host has no admitted native identity proof surface.')
        rows, source = [], 'unsupported'
    changed = bool(rows) and selection['requested']['policy'] == 'pinned'
    reason = ('actual-id-mismatch' if changed else 'actual-id-unavailable' if require_actual_id else
              'reroute-observed' if rows else 'identity-unverified')
    return {'schema': DELIVERY_SCHEMA, 'selection_sha256': selection['selection_sha256'],
            'run_id': binding['run_id'], 'session_id': binding['session_id'], 'turn_id': events['turn_id'],
            'configured_id': selection['resolved']['native_id'], 'actual_id': None, 'proof': 'unverified',
            'source': source, 'reroutes': rows, 'status': 'blocked' if changed or require_actual_id else 'accepted',
            'reason': reason}


def validate_delivery_record(record, *, selection, events, require_actual_id, transport=None):
    _fields(record, DELIVERY_FIELDS, 'Delivery')
    expected = verify_delivery(selection, events, require_actual_id=require_actual_id, transport=transport)
    try:
        matches = canonical(record) == canonical(expected)
    except (ValueError, TypeError, RecursionError):
        matches = False
    if not matches:
        raise _invalid('Delivery fields disagree with the bound selection and admitted host evidence.')


def _read_record(path):
    try:
        with path.open('rb') as stream:
            raw = stream.read(MAX_OPERATION_BYTES + 1)
    except OSError:
        raise _invalid('Input file could not be read; check its path and permissions.') from None
    if len(raw) > MAX_OPERATION_BYTES:
        raise _invalid('Input file exceeds the metadata size limit.')
    return strict_json(raw)


def _publish_record(target, record, *, selection=False):
    """Atomic complete no-replace publication; an equal incumbent resumes without rewriting its bytes."""
    handle, temp = tempfile.mkstemp(prefix='.model-record-', dir=str(target.parent))
    try:
        with os.fdopen(handle, 'wb') as stream:
            stream.write(canonical(record))
        try:
            os.link(temp, target)
        except FileExistsError:
            try:
                if target.is_symlink():
                    raise _invalid('Output is a symlink.')
                incumbent = _read_record(target)
                if selection:
                    validate_selection_record(incumbent, require_bound=True)
                if canonical(incumbent) != canonical(record):
                    raise _invalid('Existing output differs.')
            except PolicyError:
                reason = 'resume-conflict' if selection else 'input-invalid'
                raise PolicyError(reason, 'Existing output differs or is invalid; use a new attempt/output.') from None
    except OSError:
        raise _invalid('Could not publish output atomically; check the path and filesystem.') from None
    finally:
        os.unlink(temp)


def _record_command(argv):
    command = argv[0]
    names = (('--selection', '--run-id', '--session-id', '--attempt', '--output') if command == 'bind' else
             ('--selection', '--events', '--require-actual-id', '--output'))
    options, rest = {}, argv[1:]
    while rest:
        if len(rest) < 2 or rest[0] not in names or rest[0] in options:
            raise _invalid('Unknown, duplicate or incomplete record command argument.')
        options[rest[0]] = rest[1]
        rest = rest[2:]
    if set(options) != set(names):
        raise _invalid('Record command requires exactly its documented arguments.')
    target = _output_path(options['--output'])
    selection = _read_record(_output_path(options['--selection']))
    if command == 'bind':
        if not re.fullmatch(r'[1-9][0-9]*', options['--attempt']):
            raise _invalid('--attempt must be a positive ASCII decimal integer.')
        result = bind_selection(selection, run_id=options['--run-id'], session_id=options['--session-id'],
                                attempt=int(options['--attempt']))
        _publish_record(target, result, selection=True)
    else:
        if options['--require-actual-id'] not in ('true', 'false'):
            raise _invalid('--require-actual-id must be exactly true or false.')
        events = _read_record(_output_path(options['--events']))
        result = verify_delivery(selection, events, require_actual_id=options['--require-actual-id'] == 'true')
        _publish_record(target, result)
        if result['status'] == 'blocked':
            raise PolicyError(result['reason'], 'Delivery cannot satisfy the consuming identity contract.')



# ---- Role policy normalization (T-006); ranking stays in the existing selectors. ----------------------------

POLICY_ROLES = {
    'implementer': None, 'investigator': 'sdd-investigator',
    'spec-reviewer-a': 'spec-reviewer', 'spec-reviewer-b': 'spec-reviewer',
    'impl-reviewer-a': 'impl-reviewer', 'impl-reviewer-b': 'impl-reviewer',
    'task-reviewer-a': 'task-reviewer', 'task-reviewer-b': 'task-reviewer',
    'evaluator': 'sdd-evaluator', 'domain-reviewer-a': 'domain-reviewer',
    'domain-reviewer-b': 'domain-reviewer', 'workflow-auditor-a': 'workflow-auditor',
    'workflow-auditor-b': 'workflow-auditor', 'diagnosis': 'diagnosis',
    'self-improvement': 'self-improvement', 'panelist-gpt': 'panelist-gpt',
    'panelist-gemini': 'panelist-gemini',
}
POLICY_REQUEST_FIELDS = ('schema', 'role', 'risk', 'host', 'policy_path', 'observation_path',
                         'project_config_path', 'cli', 'budget', 'requested_effort', 'resume_selection_path')
SELECTOR_OPTION_NAMES = ('risk', 'role', 'host', 'requested_effort', 'required_tier', 'minimum_tier',
                        'failure_class', 'failure_history', 'previous_tier', 'consecutive_failures',
                        'attempt_number', 'xhigh_reason', 'effort_policy', 'candidate', 'candidates_file')
CAPABILITY_TIERS = ('lightweight', 'standard', 'strong')


def _config(message):
    return PolicyError('config-invalid', message)


def _config_fields(value, required, optional=()):
    if not isinstance(value, dict) or not set(required) <= set(value) or set(value) - set(required) - set(optional):
        raise _config('Configuration must contain exactly its declared fields.')


def _config_read(path):
    try:
        return _read_record(_output_path(path))
    except (PolicyError, OSError, TypeError):
        raise _config('Configuration input must be a contained readable strict JSON file.') from None


def _config_time(value):
    try:
        _parse_utc(value)
    except PolicyError:
        raise _config('Source dates must be valid UTC calendar timestamps ending in Z.') from None


def _nullable_config(value, allowed=None):
    if value is not None and not (_member(value, allowed) if allowed else _id(value)):
        raise _config('Model identifiers and policy values must use the exact supported vocabulary.')


def _money(value, *, estimate=False):
    _config_fields(value, ('catalog_id', 'amount', 'unit', 'source_url', 'source_date') if estimate else
                   ('amount', 'unit'))
    amount = value['amount']
    if (type(amount) not in (int, float) or amount < 0 or
            type(amount) is float and not math.isfinite(amount) or value['unit'] != 'USD'):
        raise _config('Monetary configuration requires a finite nonnegative USD amount.')
    if estimate:
        if not _id(value['catalog_id']) or not _https_metadata(value['source_url']):
            raise _config('Estimate identifiers and HTTPS metadata must be valid.')
        _config_time(value['source_date'])


def _validate_policy_request(request):
    _config_fields(request, POLICY_REQUEST_FIELDS, ('estimates',))
    if (request['schema'] != 'model-policy-request/v1' or not _member(request['role'], POLICY_ROLES)
            or not _member(request['risk'], ('low', 'medium', 'high', 'critical'))
            or not _member(request['host'], HOSTS)):
        raise _config('Policy request schema, role, risk or host is unsupported.')
    _config_fields(request['cli'], ('model_id', 'policy'))
    _nullable_config(request['cli']['model_id'])
    _nullable_config(request['cli']['policy'], POLICIES)
    _nullable_config(request['requested_effort'], EFFORTS)
    for field in ('policy_path', 'observation_path', 'project_config_path', 'resume_selection_path'):
        if request[field] is None and field in ('project_config_path', 'resume_selection_path'):
            continue
        try:
            _output_path(request[field])
        except (PolicyError, TypeError):
            raise _config('Policy request paths must be contained relative regular files.') from None
    if request['budget'] is not None:
        _money(request['budget'])
    estimates = request.get('estimates')
    if estimates is not None:
        if not isinstance(estimates, list):
            raise _config('Estimates must be a list or null.')
        seen = set()
        for estimate in estimates:
            _money(estimate, estimate=True)
            if estimate['catalog_id'] in seen:
                raise _config('Estimate catalog IDs must be unique.')
            seen.add(estimate['catalog_id'])


def _policy_registry(path):
    try:
        target = Path(path)
        if target.is_symlink() or not target.is_file():
            raise ValueError
        registry = _read_record(target)
    except (PolicyError, OSError, TypeError, ValueError):
        raise _config('Capability registry must be a readable regular JSON file.') from None
    _config_fields(registry, ('schema', 'models'), ('role_defaults', 'risk_effort_matrix'))
    if registry['schema'] != 'agent-model-capabilities/v2' or not isinstance(registry['models'], list):
        raise _config('Policy selection requires the v2 capability registry.')
    models = {}
    for model in registry['models']:
        _config_fields(model, ('name', 'canonical_tier', 'supported_efforts', 'default_effort', 'effort_control'),
                       ('fallback_for',))
        if not _id(model['name']) or model['name'] in models or not _member(model['canonical_tier'], CAPABILITY_TIERS):
            raise _config('Registry model IDs must be unique and have a supported canonical tier.')
        efforts = model['supported_efforts']
        if (not isinstance(efforts, list) or not efforts or not all(_member(e, EFFORTS) for e in efforts)
                or len(set(efforts)) != len(efforts) or model['default_effort'] not in efforts):
            raise _config('Registry supported/default efforts are invalid.')
        control = model['effort_control']
        if (not isinstance(control, dict) or any(not _member(k, HOSTS) or
                not _member(v, ('flag', 'frontmatter', 'none')) for k, v in control.items())):
            raise _config('Registry effort control must use explicit supported host mappings.')
        models[model['name']] = model
    defaults = registry.get('role_defaults', {})
    if not isinstance(defaults, dict):
        raise _config('Registry role defaults must be an object.')
    for value in defaults.values():
        _config_fields(value, ('minimum_tier', 'default_effort'), ('claude_frontmatter',))
        for profile in (value, value.get('claude_frontmatter')):
            if profile is None:
                continue
            if profile is not value:
                _config_fields(profile, ('minimum_tier', 'default_effort'))
            if not _member(profile['minimum_tier'], CAPABILITY_TIERS) or not _member(profile['default_effort'], EFFORTS):
                raise _config('Registry role floor or default effort is unsupported.')
    matrix = registry.get('risk_effort_matrix', {})
    if not isinstance(matrix, dict):
        raise _config('Registry risk effort matrix must be an object.')
    for key, value in matrix.items():
        if key == 'escalation_bump':
            if type(value) is not bool:
                raise _config('Escalation bump must be boolean.')
        elif key not in ('low', 'medium', 'high', 'critical') or not _member(value, EFFORTS):
            raise _config('Registry risk effort matrix contains unsupported values.')
    return registry, models


def _validate_role_policy(policy, registered, defaults):
    _config_fields(policy, ('schema', 'source_date', 'observation_max_age_seconds', 'default_policy', 'roles', 'models'))
    if (policy['schema'] != 'model-policy/v1' or policy['default_policy'] != 'latest-compatible'
            or type(policy['observation_max_age_seconds']) is not int or policy['observation_max_age_seconds'] <= 0):
        raise _config('Policy schema, default or observation freshness limit is invalid.')
    _config_time(policy['source_date'])
    if not isinstance(policy['roles'], dict) or set(policy['roles']) != set(POLICY_ROLES):
        raise _config('Policy must define exactly the supported managed roles.')
    if not isinstance(policy['models'], list):
        raise _config('Policy models must be a list.')
    models, mappings = {}, set()
    for model in policy['models']:
        _config_fields(model, ('id', 'lifecycle', 'source_url', 'source_date', 'successor_of', 'hosts', 'adoption'))
        name = model['id']
        if not _id(name) or name not in registered or name in models:
            raise _config('Policy model IDs must be unique registered capabilities.')
        if not _member(model['lifecycle'], ('current', 'candidate', 'historical', 'retired')):
            raise _config('Policy lifecycle must use an exact supported value.')
        if not _https_metadata(model['source_url']):
            raise _config('Policy source URL must be HTTPS metadata.')
        _config_time(model['source_date'])
        if not isinstance(model['hosts'], dict):
            raise _config('Policy host mappings must be an object.')
        for host, native in model['hosts'].items():
            if not _member(host, HOSTS) or not _id(native) or (host, native) in mappings:
                raise _config('Policy native host mappings must be supported, exact and unambiguous.')
            mappings.add((host, native))
        successors = model['successor_of']
        if (not isinstance(successors, list) or not all(_id(x) for x in successors)
                or len(set(successors)) != len(successors)):
            raise _config('Successor references must be unique model IDs.')
        if not isinstance(model['adoption'], list):
            raise _config('Role adoption references must be a list.')
        roles = set()
        for reference in model['adoption']:
            _config_fields(reference, ('role', 'path', 'sha256'))
            if not _member(reference['role'], POLICY_ROLES) or reference['role'] in roles or not _hash(reference['sha256']):
                raise _config('Adoption role/hash references must be supported and unique.')
            roles.add(reference['role'])
            try:
                path = _output_path(reference['path'])
                if path.stat().st_size > 16 * 1024 * 1024 or hashlib.sha256(path.read_bytes()).hexdigest() != reference['sha256']:
                    raise ValueError
            except (PolicyError, OSError, TypeError, ValueError):
                raise _config('Adoption reference must match the contained evidence file bytes.') from None
        models[name] = model
    for role, value in policy['roles'].items():
        _config_fields(value, ('capability_role', 'model_env', 'preferences'))
        if (value['capability_role'] != POLICY_ROLES[role] or
                value['capability_role'] is not None and value['capability_role'] not in defaults):
            raise _config('Managed role must reference its existing registry capability role.')
        if value['model_env'] != 'SDD_MODEL_' + role.upper().replace('-', '_'):
            raise _config('Managed role model environment key is not the documented exact key.')
        preferences = value['preferences']
        if (not isinstance(preferences, list) or not all(_id(x) and x in models for x in preferences)
                or len(set(preferences)) != len(preferences)):
            raise _config('Role preferences must contain unique registered policy model IDs.')
    active, complete = set(), set()

    def visit(name):
        if name not in models or name in active:
            raise _config('Successor graph has an unresolved reference or cycle.')
        if name in complete:
            return
        active.add(name)
        for prior in models[name]['successor_of']:
            visit(prior)
        active.remove(name)
        complete.add(name)

    for name in models:
        visit(name)
    return models


def _effective_configuration(request, policy, project, environment):
    _config_fields(project, ('schema', 'default_policy', 'roles'))
    if project['schema'] != 'model-role-config/v1' or not isinstance(project['roles'], dict):
        raise _config('Project model role configuration schema is invalid.')
    _nullable_config(project['default_policy'], POLICIES)
    for role, value in project['roles'].items():
        if role not in POLICY_ROLES:
            raise _config('Project configuration contains an unsupported role.')
        _config_fields(value, ('model_id', 'policy'))
        _nullable_config(value['model_id'])
        _nullable_config(value['policy'], POLICIES)
    keys = {value['model_env'] for value in policy['roles'].values()}
    for key, value in environment.items():
        if not key.startswith('SDD_MODEL'):
            continue
        if key == 'SDD_MODEL_POLICY':
            if not _member(value, POLICIES):
                raise _config('SDD_MODEL_POLICY must be exactly latest-compatible or pinned.')
        elif key in keys:
            if not _id(value):
                raise _config('Every supplied role model environment value must be a valid model ID.')
        else:
            raise _config('Generic or unsupported model environment configuration is not supported.')
    role = project['roles'].get(request['role'], {'model_id': None, 'policy': None})
    model_sources = [(request['cli']['model_id'], 'cli'),
                     (environment.get(policy['roles'][request['role']]['model_env']), 'environment'),
                     (role['model_id'], 'project-role')]
    policy_sources = [(request['cli']['policy'], 'cli'), (environment.get('SDD_MODEL_POLICY'), 'environment'),
                      (role['policy'], 'project-role'), (project['default_policy'], 'project-default')]
    model, model_source = next(((v, source) for v, source in model_sources if v is not None), (None, None))
    selected_policy, policy_source = next(((v, source) for v, source in policy_sources if v is not None), (None, None))
    if selected_policy is None:
        selected_policy, policy_source = ('pinned', model_source) if model is not None else (policy['default_policy'], 'shipped')
    if (selected_policy == 'pinned') != (model is not None):
        raise PolicyError('config-conflict', 'Pinned policy requires an explicit ID; explicit latest-compatible cannot accompany one.')
    return {'policy': selected_policy, 'model_id': model, 'policy_source': policy_source, 'model_source': model_source}



def _validate_selector_options(options, request):
    """Validate supported input grammar before either native engine interprets it."""
    if not isinstance(options, dict) or set(options) - set(SELECTOR_OPTION_NAMES):
        raise _config('Selector options contain unsupported fields.')
    failures = ('test', 'lint', 'typecheck', 'build', 'review-major', 'review-critical')
    for key, value in options.items():
        if key in ('candidate', 'candidates_file'):
            raise PolicyError('config-conflict', 'Policy input cannot be combined with independent candidates.')
        if not isinstance(value, str):
            raise _config('Selector options must be strings.')
        if key in ('risk', 'role', 'host', 'requested_effort') and value != request[key]:
            raise PolicyError('config-conflict', 'Explicit selector options must equal their policy request counterparts.')
        if key in ('required_tier', 'minimum_tier', 'previous_tier') and value not in ('', *CAPABILITY_TIERS):
            raise _config('Selector tiers must use an exact supported value.')
        if key == 'effort_policy' and value not in ('matrix', 'welded'):
            raise _config('Selector effort policy must use an exact supported value.')
        if key == 'failure_class' and value and value not in failures:
            raise _config('Selector failure class must use an exact supported value.')
        if key == 'failure_history' and value and any(item not in failures for item in value.split(',')):
            raise _config('Selector failure history must contain exact supported values.')
        if key in ('consecutive_failures', 'attempt_number') and (
                not re.fullmatch(r'[0-9]+', value) or len(value) > 10 or int(value) > 2147483647):
            raise _config('Selector recurrence and attempt must be nonnegative portable integers.')
    history = options.get('failure_history', '').split(',') if options.get('failure_history') else []
    recurrence = (2 if len(history) >= 2 and history[-1] == history[-2] else 1) if history else int(options.get('consecutive_failures', '0'))
    if recurrence >= 2 and (not (history or options.get('failure_class')) or
            not options.get('previous_tier') or int(options.get('attempt_number', '0')) < 1):
        raise _config('Selector recurrence requires a failure class, previous tier and positive attempt.')


def prepare_policy(request_path, registry_path, *, options=None, environment=None, capture=None, now=None):
    """Normalize policy/configuration and availability without choosing a tier, effort or winner."""
    request = _config_read(request_path)
    _validate_policy_request(request)
    options = {} if options is None else options
    _validate_selector_options(options, request)
    policy = _config_read(request['policy_path'])
    registry, registered = _policy_registry(registry_path)
    models = _validate_role_policy(policy, registered, registry.get('role_defaults', {}))
    project = (_config_read(request['project_config_path']) if request['project_config_path'] else
               {'schema': 'model-role-config/v1', 'default_policy': None, 'roles': {}})
    requested = _effective_configuration(request, policy, project, _policy_environment(environment))
    observation = _config_read(request['observation_path'])
    validate_observation_record(observation)
    if observation['host'] != request['host']:
        raise PolicyError('scope-mismatch', 'Observation host differs from the request.')
    if observation['status'] == 'unavailable' or observation['source'] == 'unsupported':
        raise PolicyError('discovery-unavailable', 'Host availability is unavailable; obtain a supported fresh observation.')
    if observation['status'] != 'complete':
        raise PolicyError('discovery-incomplete', 'Selection requires a complete observation.')
    if observation['source'] == 'live-discovery':
        if not isinstance(capture, Capture):
            raise PolicyError('scope-mismatch', 'Persisted live discovery is not an active capture witness.')
        validate_observation(observation, capture=capture, purpose='launch', now=now,
                             max_age_seconds=policy['observation_max_age_seconds'])
    else:
        validate_configuration(observation, now=now, max_age_seconds=policy['observation_max_age_seconds'])
    observed = {x['native_id']: x for x in observation['models']}
    role = policy['roles'][request['role']]
    preferences = role['preferences']
    estimate_map = {x['catalog_id']: x for x in request.get('estimates') or []}
    if any(name not in registered for name in estimate_map):
        raise _config('Estimate references an unknown registry model.')
    chosen_id = requested['model_id']
    if chosen_id is not None and chosen_id not in models:
        raise PolicyError('model-unavailable', 'Explicit model is not in the registered policy.')
    candidates, rejected = [], set()
    for name, model in models.items():
        if chosen_id is not None and name != chosen_id:
            continue
        if chosen_id is None and model['lifecycle'] != 'current':
            continue
        if not any(a['role'] == request['role'] for a in model['adoption']):
            rejected.add('model-unverified')
            continue
        native = model['hosts'].get(request['host'])
        seen = observed.get(native)
        definition = registered[name]
        if not seen or not seen['available'] or request['host'] not in definition['effort_control']:
            rejected.add('model-unavailable')
            continue
        supported = [x for x in definition['supported_efforts'] if x in seen['efforts']]
        if not supported or request['requested_effort'] is not None and request['requested_effort'] not in supported:
            rejected.add('effort-unavailable')
            continue
        estimate = estimate_map.get(name)
        if request['budget'] is not None and (estimate is None or estimate['amount'] > request['budget']['amount']):
            rejected.add('budget-unverifiable')
            continue
        candidates.append({'name': name, 'available': True, 'cost': None if estimate is None else ('0' if estimate['amount'] == 0 else str(estimate['amount'])),
                           'preference': preferences.index(name) if name in preferences else len(preferences),
                           'native_id': native, 'allowed_efforts': supported, 'successor_of': model['successor_of']})
    if not candidates:
        reason = next((x for x in ('budget-unverifiable', 'effort-unavailable', 'model-unavailable', 'model-unverified')
                       if x in rejected), 'model-unverified')
        raise PolicyError(reason, 'No verified available candidate satisfies the role policy; refresh evidence or use an eligible explicit pin.')
    known_native = {m['hosts'][request['host']] for m in models.values() if request['host'] in m['hosts']}
    updates = sorted({x['native_id'] for x in observation['models'] if x['available'] and x['native_id'] not in known_native}
                     | {m['id'] for m in models.values() if m['lifecycle'] == 'candidate'
                        and m['hosts'].get(request['host']) in observed})
    profile = registry.get('role_defaults', {}).get(role['capability_role'], {})
    if request['host'] == 'claude-code' and 'claude_frontmatter' in profile:
        profile = profile['claude_frontmatter']
    return {'schema': 'model-policy-preparation/v1', 'request_path': request_path, 'registry_path': registry_path,
            'selector_options': options, 'request': request, 'policy': policy, 'registry': registry,
            'observation': observation, 'requested': requested, 'role_profile': profile,
            'capability_role': role['capability_role'], 'candidates': candidates, 'update_candidates': updates}


def _replay_policy_winner(context):
    """Replay the fixed native selector; the private mode emits an unsealed proposal only."""
    snapshot_root = _SNAPSHOT_ROOT.get()
    folder = (Path(__file__).resolve().parent if snapshot_root is None else
              snapshot_root / 'plugins/sdd-implementation/scripts')
    windows = os.name == 'nt'
    executable = shutil.which('pwsh' if windows else 'bash')
    if executable is None:
        raise PolicyError('input-invalid', 'The platform native selector runtime is unavailable.')
    if windows:
        command = [executable, '-NoProfile', '-File', str(folder / 'select-agent-model.ps1'),
                   '-PolicyEngineOnly', '-PolicyInput', context['request_path'], '-Registry', context['registry_path']]
        names = {'host': 'HostName', 'role': 'Role', 'risk': 'Risk', 'requested_effort': 'RequestedEffort',
                 'required_tier': 'RequiredTier', 'minimum_tier': 'MinimumTier', 'failure_class': 'FailureClass',
                 'failure_history': 'FailureHistory', 'previous_tier': 'PreviousTier',
                 'consecutive_failures': 'ConsecutiveFailures', 'attempt_number': 'AttemptNumber',
                 'xhigh_reason': 'XhighReason', 'effort_policy': 'EffortPolicy'}
        for key, value in context['selector_options'].items():
            command.extend(['-' + names[key], value])
    else:
        command = [executable, str(folder / 'select-agent-model.sh'), '--policy-engine-only',
                   '--policy-input', context['request_path'], '--registry', context['registry_path']]
        for key, value in context['selector_options'].items():
            command.extend(['--' + key.replace('_', '-'), value])
    payload = canonical(context)
    if len(payload) > 16 * 1024 * 1024:
        raise _invalid('Prepared selection exceeds the supported bridge size.')
    # Fixed trusted selector writes only a small proposal/error; files additionally bound captured memory.
    try:
        with tempfile.TemporaryFile() as output, tempfile.TemporaryFile() as errors:
            process = subprocess.run(command, input=payload, stdout=output, stderr=errors, timeout=30, check=False,
                                     cwd=_SNAPSHOT_ROOT.get())
            if output.tell() > 65536 or errors.tell() > 65536:
                raise _invalid('Native selector output exceeded the supported bridge size.')
            output.seek(0)
            errors.seek(0)
            raw, diagnostic = output.read(65537), errors.read(65537)
    except (OSError, subprocess.TimeoutExpired):
        raise _invalid('The platform native selector could not complete within its bounded runtime.') from None
    if process.returncode != 0 or diagnostic:
        raise PolicyError('model-tier-unavailable', 'The native selector rejected the prepared capability request.')
    result = strict_json(raw)
    _fields(result, ('model', 'canonical_tier', 'effort', 'effort_control'), 'Native selector proposal')
    return result


def complete_policy(context, winner, *, capture=None, now=None):
    """Validate a selector-produced choice and reuse the immutable T-005 record contract."""
    if not isinstance(context, dict):
        raise _invalid('Completion requires the prepared selection context.')
    current = prepare_policy(context.get('request_path'), context.get('registry_path'),
                             options=context.get('selector_options'), capture=capture, now=now)
    if canonical(current) != canonical(context):
        raise PolicyError('config-conflict', 'Selection inputs changed after preparation; resolve again.')
    _fields(winner, ('model', 'canonical_tier', 'effort', 'effort_control'), 'Selector winner')
    candidate = next((x for x in context['candidates'] if x['name'] == winner['model']), None)
    if candidate is None:
        raise PolicyError('model-unavailable', 'Winner is not an admitted policy candidate.')
    definition = next(x for x in context['registry']['models'] if x['name'] == winner['model'])
    if winner['canonical_tier'] != definition['canonical_tier']:
        raise PolicyError('model-tier-unavailable', 'Winner tier differs from its registered capability.')
    profile, options = context['role_profile'], context['selector_options']
    for minimum in (profile.get('minimum_tier'), options.get('minimum_tier') or None):
        if minimum is not None and (minimum not in CAPABILITY_TIERS or
                CAPABILITY_TIERS.index(definition['canonical_tier']) < CAPABILITY_TIERS.index(minimum)):
            raise PolicyError('model-tier-unavailable', 'Winner cannot lower the role or caller minimum tier.')
    if options.get('required_tier') and options['required_tier'] != definition['canonical_tier']:
        raise PolicyError('model-tier-unavailable', 'Winner differs from the required tier.')
    request, observation = context['request'], context['observation']
    if (winner['effort'] not in candidate['allowed_efforts'] or
            winner['effort_control'] != definition['effort_control'][request['host']] or
            request['requested_effort'] is not None and winner['effort'] != request['requested_effort'] or
            winner['effort'] == 'xhigh' and not options.get('xhigh_reason')):
        raise PolicyError('effort-unavailable', 'Winner effort/control does not satisfy the admitted host and request.')
    expected = _replay_policy_winner(context)
    if canonical(expected) != canonical(winner):
        raise PolicyError('model-tier-unavailable', 'Proposed winner differs from the native capability/risk/effort selection.')
    # Recheck source bytes and the in-process witness after the bounded native replay.
    current = prepare_policy(context.get('request_path'), context.get('registry_path'),
                             options=context.get('selector_options'), capture=capture, now=now)
    if canonical(current) != canonical(context):
        raise PolicyError('config-conflict', 'Selection inputs changed during selection; resolve again.')
    estimate = next((x for x in request.get('estimates') or [] if x['catalog_id'] == winner['model']), None)
    label = 'pinned' if context['requested']['policy'] == 'pinned' else 'latest-verified'
    record = {'schema': SELECTION_SCHEMA, 'role': request['role'], 'risk': request['risk'], 'host': request['host'],
              'cli_version': observation['cli_version'], 'scope_id': observation['scope_id'],
              'requested': context['requested'], 'resolved': {'catalog_id': winner['model'],
                  'native_id': candidate['native_id'], 'effort': winner['effort'], 'effort_control': winner['effort_control']},
              'policy_sha256': hashlib.sha256(canonical(context['policy'])).hexdigest(),
              'catalog_sha256': hashlib.sha256(canonical(context['registry'])).hexdigest(),
              'observation_sha256': observation['observation_sha256'], 'observed_at': observation['observed_at'],
              'source_date': context['policy']['source_date'],
              'reason': label + '; ' + observation['source'] + '; configuration is not execution or organization access proof.',
              'update_candidates': context['update_candidates'], 'binding': None,
              'budget': request['budget'], 'estimate': estimate}
    record['selection_sha256'] = selection_digest(record)
    validate_selection_record(record)
    if request['resume_selection_path'] is not None:
        original = _config_read(request['resume_selection_path'])
        validate_resume_selection(original, record)
        return original
    return record


def _selection_bridge(argv):
    if len(argv) != 1:
        raise _invalid('Selection bridge accepts one command and one closed JSON object on stdin.')
    raw = sys.stdin.buffer.read(16 * 1024 * 1024 + 1)
    if len(raw) > 16 * 1024 * 1024:
        raise _invalid('Selection bridge input exceeds the supported size.')
    payload = strict_json(raw)
    if argv[0] == 'prepare-selection':
        _fields(payload, ('request_path', 'registry_path', 'selector_options'), 'Selection preparation')
        result = prepare_policy(payload['request_path'], payload['registry_path'], options=payload['selector_options'])
    else:
        _fields(payload, ('context', 'winner'), 'Selection completion')
        result = complete_policy(payload['context'], payload['winner'])
    sys.stdout.buffer.write(canonical(result) + b'\n')


def _policy_environment(environment):
    """Explicit environment wins; otherwise the active captured launch environment, else the process environment."""
    if environment is not None:
        return environment
    captured = _CAPTURED_ENVIRONMENT.get()
    return os.environ if captured is None else captured


# ---- Bounded launch controls (T-007); existing T-005/T-006 functions remain the only selection logic. -------

LAUNCH_CONTROLS_SCHEMA = 'model-launch-controls/v1'
LAUNCH_VALIDATION_SCHEMA = 'model-launch-validation/v1'
LAUNCH_CONTROLS_FIELDS = frozenset(('schema', 'role', 'host', 'attempt', 'require_actual_id', 'selection', 'request',
                                    'registry', 'inputs'))
CONTROL_REFERENCE_FIELDS = ('path', 'sha256')
CONTROL_REQUEST_REFERENCES = ('policy_path', 'observation_path', 'project_config_path', 'resume_selection_path')
MAX_CONTROL_INPUTS = 1024
MAX_CONTROL_PATH = 1024
_CONTROL_COMPONENT = r'[^/\\:\x00-\x1f\x7f]{0,254}[^/\\:\x00-\x1f\x7f. ]'
CONTROL_PATH_RE = re.compile(_CONTROL_COMPONENT + '(?:/' + _CONTROL_COMPONENT + ')*')
LAUNCH_OPTIONS = ('--controls', '--controls-sha256', '--role', '--host', '--run-id', '--session-id')


def _control_path(value):
    """Canonical relative path syntax: exact nonempty components, no '.', '..', backslash, drive or control text."""
    return isinstance(value, str) and len(value) <= MAX_CONTROL_PATH and CONTROL_PATH_RE.fullmatch(value) is not None


def _safe_open_flags():
    """Descriptor-relative no-follow primitives; fail closed (including Windows) when the runtime lacks them."""
    nofollow, directory = getattr(os, 'O_NOFOLLOW', None), getattr(os, 'O_DIRECTORY', None)
    nonblocking = getattr(os, 'O_NONBLOCK', None)
    if (type(nofollow) is not int or type(directory) is not int or type(nonblocking) is not int
            or os.open not in os.supports_dir_fd
            or os.listdir not in os.supports_fd):
        raise _invalid('This runtime cannot open control inputs descriptor-relative without following symlinks.')
    return nofollow, directory


def _open_directory(path, flags, identity=None):
    """Directory descriptor for a control base; an optional (device, inode) identity must be unchanged."""
    try:
        descriptor = os.open(path, os.O_RDONLY | flags[1] | getattr(os, 'O_CLOEXEC', 0))
    except OSError:
        raise _invalid('A control base directory could not be opened.') from None
    try:
        status = os.fstat(descriptor)
    except OSError:
        os.close(descriptor)
        raise _invalid('A control base directory could not be inspected.') from None
    if identity is not None and (status.st_dev, status.st_ino) != identity:
        os.close(descriptor)
        raise _invalid('A control base directory changed during validation; validate again.')
    return descriptor, (status.st_dev, status.st_ino)


def _read_beneath(base, path, limit, flags):
    """Exact-case regular file below base via O_NOFOLLOW opens of every component; at most limit bytes."""
    if not _control_path(path):
        raise _invalid('Control paths must be canonical relative paths.')
    nofollow, directory = flags
    common = os.O_RDONLY | nofollow | getattr(os, 'O_CLOEXEC', 0)
    final = common | os.O_NONBLOCK | getattr(os, 'O_NOCTTY', 0)  # FIFOs never block the open
    parts = path.split('/')
    opened: list[int] = []
    try:
        current = base
        for index, name in enumerate(parts):
            if name not in os.listdir(current):
                raise _invalid('Control path components must exist with exact case.')
            current = os.open(name, final if index == len(parts) - 1 else common | directory, dir_fd=current)
            opened.append(current)
        status = os.fstat(current)
        if not stat.S_ISREG(status.st_mode):
            raise _invalid('Control paths must name regular files.')
        if status.st_size > limit:
            raise _invalid('Control inputs exceed the bounded snapshot size.')
        chunks: list[bytes] = []
        size = 0
        while True:
            chunk = os.read(current, min(65536, limit + 1 - size))
            if not chunk:
                return b''.join(chunks)
            chunks.append(chunk)
            size += len(chunk)
            if size > limit:
                raise _invalid('Control inputs exceed the bounded snapshot size.')
    except OSError:
        raise _invalid('A control path could not be opened safely; symlinks and special files are rejected.') from None
    finally:
        for descriptor in reversed(opened):
            os.close(descriptor)


def _read_files(base, paths, budget, flags):
    """Raw bytes of unique paths; their aggregate size never exceeds budget."""
    captured: dict[str, bytes] = {}
    for path in sorted(set(paths)):
        raw = _read_beneath(base, path, budget, flags)
        budget -= len(raw)
        captured[path] = raw
    return captured


def _read_tree(root, paths, flags, identity=None):
    base, identity = _open_directory(root, flags, identity)
    try:
        return identity, _read_files(base, paths, MAX_OPERATION_BYTES, flags)
    finally:
        os.close(base)


def _trusted_inventory():
    """Installed runtime root and fixed trusted files, derived only from this helper's own location."""
    helper = Path(__file__).resolve()
    root = helper.parents[3]
    folder = helper.parent.relative_to(root).as_posix()
    return root, sorted([helper.relative_to(root).as_posix(), folder + '/select-agent-model.sh',
                         folder + '/select-agent-model.ps1', 'contracts/agent-model-capabilities.v2.json',
                         'contracts/model-policy.v1.json', 'contracts/model-launch-controls.schema.json'])


def _capture_environment(environment):
    source = os.environ if environment is None else environment
    if not isinstance(source, Mapping) or not all(isinstance(k, str) and isinstance(v, str) for k, v in source.items()):
        raise _invalid('environment must map strings to strings.')
    return MappingProxyType(dict(source))


def _control_reference(value):
    _fields(value, CONTROL_REFERENCE_FIELDS, 'Control reference')
    if not _control_path(value['path']) or not _hash(value['sha256']):
        raise _invalid('Control references require a canonical relative path and lowercase raw SHA-256.')
    return value['path'], value['sha256']


def _launch_document(document):
    """Closed model-launch-controls/v1 document; returns (inputs, unique pin map of every reference)."""
    _fields(document, LAUNCH_CONTROLS_FIELDS, 'Launch controls')
    if (document['schema'] != LAUNCH_CONTROLS_SCHEMA or not _member(document['role'], POLICY_ROLES)
            or not _member(document['host'], HOSTS) or type(document['attempt']) is not int
            or document['attempt'] <= 0 or type(document['require_actual_id']) is not bool):
        raise _invalid('Launch controls schema, role, host, attempt or require_actual_id is invalid.')
    entries = document['inputs']
    if not isinstance(entries, list) or not 0 < len(entries) <= MAX_CONTROL_INPUTS:
        raise _invalid('Launch control inputs must be a bounded nonempty list.')
    listed = [_control_reference(entry) for entry in entries]
    paths = [path for path, _ in listed]
    if paths != sorted(set(paths)):
        raise _invalid('Launch control inputs must be sorted by path with unique paths.')
    pins: dict[str, str] = {}
    for path, sha in [_control_reference(document[k]) for k in ('selection', 'request', 'registry')] + listed:
        if pins.setdefault(path, sha) != sha:
            raise _invalid('One control path is pinned to different raw SHA-256 values.')
    return dict(listed), pins


def _launch_closure(request_raw, inputs, captured):
    """Resolve request and policy references only within the captured pins; return the parsed request and policy."""
    request = strict_json(request_raw)
    if any(field not in request for field in CONTROL_REQUEST_REFERENCES):
        raise _config('Policy request must declare its policy, observation, project and resume references.')
    references = set()
    for field in CONTROL_REQUEST_REFERENCES:
        if request[field] is None and field in ('project_config_path', 'resume_selection_path'):
            continue
        if not _control_path(request[field]):
            raise _config('Policy request references must be canonical relative paths.')
        references.add(request[field])
    if not references <= set(inputs):
        raise _invalid('Policy request references a path that is not a pinned control input.')
    policy = strict_json(captured[request['policy_path']])
    models = policy.get('models')
    if not isinstance(models, list):
        raise _config('Policy models must be a list.')
    adoption: dict[str, str] = {}
    for model in models:
        refs = model.get('adoption') if isinstance(model, dict) else None
        if not isinstance(refs, list):
            raise _config('Role adoption references must be a list.')
        for ref in refs:
            if not isinstance(ref, dict) or not _control_path(ref.get('path')) or not _hash(ref.get('sha256')):
                raise _config('Adoption references require canonical relative paths and raw SHA-256 values.')
            if adoption.setdefault(ref['path'], ref['sha256']) != ref['sha256']:
                raise PolicyError('config-conflict', 'One adoption path is referenced with different SHA-256 values.')
    if references | set(adoption) != set(inputs):
        raise _invalid('Launch control inputs must equal the exact request and policy adoption closure.')
    if any(inputs[path] != sha for path, sha in adoption.items()):
        raise PolicyError('config-conflict', 'Adoption references disagree with their pinned control inputs.')
    return request, policy


def _policy_mappings(policy):
    models = policy.get('models') if isinstance(policy, dict) else None
    if not isinstance(models, list) or not all(
            isinstance(m, dict) and _id(m.get('id')) and isinstance(m.get('hosts'), dict) for m in models):
        raise _config('Policy models must declare identifiers and native host mappings.')
    mappings = {m['id']: m['hosts'] for m in models}
    if len(mappings) != len(models):
        raise _config('Policy model IDs must be unique.')
    return mappings


def _launch_authority(registry_raw, policy, trusted_registry_raw, trusted_policy_raw):
    """Caller registry and model/native mappings must equal the trusted installed contracts; labels confer nothing."""
    if canonical(strict_json(registry_raw)) != canonical(strict_json(trusted_registry_raw)):
        raise PolicyError('config-conflict', 'Supplied capability registry differs from the trusted registry.')
    supplied_mappings = _policy_mappings(policy)
    trusted_mappings = _policy_mappings(strict_json(trusted_policy_raw))
    if any(name not in trusted_mappings or canonical(hosts) != canonical(trusted_mappings[name])
           for name, hosts in supplied_mappings.items()):
        raise PolicyError('config-conflict', 'Supplied policy model IDs or native host mappings differ from trusted.')


def _write_snapshot(root, captured, paths):
    try:
        for path in sorted(set(paths)):
            target = root.joinpath(*path.split('/'))
            target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            with open(target, 'xb') as stream:
                stream.write(captured[path])
    except OSError:
        raise _invalid('The private control snapshot could not be written.') from None


def _scoped_selection(root, environment, request_path, registry_path, capture, now):
    """Existing prepare/replay/complete over the private snapshot with the captured environment; tokens always reset."""
    root_token = _SNAPSHOT_ROOT.set(root)
    try:
        environment_token = _CAPTURED_ENVIRONMENT.set(environment)
        try:
            context = prepare_policy(request_path, registry_path, options={}, capture=capture, now=now)
            winner = _replay_policy_winner(context)
            return complete_policy(context, winner, capture=capture, now=now)
        finally:
            _CAPTURED_ENVIRONMENT.reset(environment_token)
    finally:
        _SNAPSHOT_ROOT.reset(root_token)


def _launch_selection(computed, caller, *, run_id, session_id, attempt):
    """Every immutable caller leaf must equal the recomputation; T-005 bind/resume then fix the actual context."""
    if computed['binding'] is None:
        for field in sorted(SELECTION_FIELDS - {'selection_sha256', 'binding'}):
            if canonical(caller[field]) != canonical(computed[field]):
                raise PolicyError('config-conflict', 'Selection ' + field + ' differs from the trusted recomputation.')
    else:
        validate_resume_selection(computed, caller)
    expected = bind_selection(computed, run_id=run_id, session_id=session_id, attempt=attempt)
    if canonical(bind_selection(caller, run_id=run_id, session_id=session_id, attempt=attempt)) != canonical(expected):
        raise PolicyError('config-conflict', 'Selection differs from the trusted recomputation.')
    return expected


def validate_launch_controls(controls_path, controls_sha256, *, role, host, run_id, session_id, native_model=None,
                             capture=None, now=None, environment=None):
    """Validate closed raw-pinned launch controls; return the trusted recomputed selection bound to this launch."""
    if not _control_path(controls_path) or not _hash(controls_sha256):
        raise _invalid('Controls require a canonical relative path and a lowercase raw SHA-256 pin.')
    if (not _member(role, POLICY_ROLES) or not _member(host, HOSTS) or not _id(run_id) or not _id(session_id)
            or native_model is not None and not _id(native_model)):
        raise _invalid('Launch role, host, run, session or native model is invalid.')
    flags = _safe_open_flags()
    captured_environment = _capture_environment(environment)
    trusted_root, trusted_paths = _trusted_inventory()
    trusted_identity, trusted = _read_tree(str(trusted_root), trusted_paths, flags)
    base, identity = _open_directory('.', flags)
    try:
        controls_raw = _read_beneath(base, controls_path, MAX_OPERATION_BYTES, flags)
        if hashlib.sha256(controls_raw).hexdigest() != controls_sha256:
            raise _invalid('Controls bytes do not match the supplied raw SHA-256 pin.')
        document = strict_json(controls_raw)
        inputs, pins = _launch_document(document)
        if document['role'] != role or document['host'] != host:
            raise PolicyError('scope-mismatch', 'Launch controls role or host differs from the actual invocation.')
        if controls_path in pins:
            raise _invalid('Launch controls cannot pin themselves as a selection input.')
        captured = _read_files(base, pins, MAX_OPERATION_BYTES - len(controls_raw), flags)
    finally:
        os.close(base)
    if any(hashlib.sha256(captured[path]).hexdigest() != sha for path, sha in pins.items()):
        raise _invalid('A control input does not match its raw SHA-256 pin.')
    request_path, registry_path = document['request']['path'], document['registry']['path']
    request, policy = _launch_closure(captured[request_path], inputs, captured)
    if request.get('role') != role or request.get('host') != host:
        raise PolicyError('scope-mismatch', 'Policy request role or host differs from the actual invocation.')
    selection = strict_json(captured[document['selection']['path']])
    validate_selection_record(selection)
    if selection['role'] != role or selection['host'] != host:
        raise PolicyError('scope-mismatch', 'Selection role or host differs from the actual invocation.')
    _launch_authority(captured[registry_path], policy, trusted['contracts/agent-model-capabilities.v2.json'],
                      trusted['contracts/model-policy.v1.json'])
    if document['require_actual_id']:
        raise PolicyError('actual-id-unavailable', 'No admitted pre-launch surface can establish the actual model ID.')
    try:
        root = Path(tempfile.mkdtemp(prefix='model-launch-')).resolve()
    except OSError:
        raise _invalid('The private control snapshot could not be created.') from None
    try:
        snapshot = dict(trusted)
        for path in [request_path, registry_path, *inputs]:
            if path in snapshot and snapshot[path] != captured[path]:
                raise PolicyError('config-conflict', 'Control path conflicts with the captured trusted runtime.')
            snapshot[path] = captured[path]
        _write_snapshot(root, snapshot, snapshot)
        computed = _scoped_selection(root, captured_environment, request_path,
                                     str(root.joinpath(*registry_path.split('/'))), capture, now)
    finally:
        shutil.rmtree(root, ignore_errors=True)
    bound = _launch_selection(computed, selection, run_id=run_id, session_id=session_id, attempt=document['attempt'])
    if native_model is not None and native_model != bound['resolved']['native_id']:
        raise PolicyError('native-precedence-conflict', 'Native model differs from the selected configured native ID.')
    # Recheck original and trusted bytes at the boundary; only already-listed paths are reopened, never parsed.
    _, current = _read_tree('.', [controls_path, *pins], flags, identity)
    if (hashlib.sha256(current.pop(controls_path)).hexdigest() != controls_sha256
            or any(hashlib.sha256(current[path]).hexdigest() != sha for path, sha in pins.items())
            or _read_tree(str(trusted_root), trusted_paths, flags, trusted_identity)[1] != trusted):
        raise _invalid('Pinned control or trusted runtime bytes changed during validation; validate again.')
    return {'schema': LAUNCH_VALIDATION_SCHEMA, 'controls': {'path': controls_path, 'sha256': controls_sha256},
            'pins': [{'path': path, 'sha256': pins[path]} for path in sorted(pins)],
            'trusted': [{'path': path, 'sha256': hashlib.sha256(trusted[path]).hexdigest()} for path in trusted_paths],
            'role': role, 'host': host, 'run_id': run_id, 'session_id': session_id, 'attempt': document['attempt'],
            'require_actual_id': document['require_actual_id'], 'selection': bound}


def _launch_controls_command(argv):
    options, rest = {}, argv[1:]
    while rest:
        if len(rest) < 2 or rest[0] not in LAUNCH_OPTIONS + ('--native-model',) or rest[0] in options:
            raise _invalid('Unknown, duplicate or incomplete launch-controls argument.')
        options[rest[0]] = rest[1]
        rest = rest[2:]
    if not set(LAUNCH_OPTIONS) <= set(options):
        raise _invalid('launch-controls requires --controls, --controls-sha256, --role, --host, --run-id and '
                       '--session-id.')
    result = validate_launch_controls(options['--controls'], options['--controls-sha256'], role=options['--role'],
                                      host=options['--host'], run_id=options['--run-id'],
                                      session_id=options['--session-id'], native_model=options.get('--native-model'))
    sys.stdout.buffer.write(canonical(result) + b'\n')


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
    root = _SNAPSHOT_ROOT.get()
    base = Path.cwd().resolve() if root is None else root
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
        if argv and argv[0] in ('prepare-selection', 'complete-selection'):
            _selection_bridge(argv)
        elif argv and argv[0] in ('bind', 'verify-delivery'):
            _record_command(argv)
        elif argv and argv[0] == 'launch-controls':
            _launch_controls_command(argv)
        else:
            _discover(*_parse_discover(argv))
        return 0
    except PolicyError as failure:
        error = failure
    except Exception:  # closed envelope only; never a traceback or raw native text
        error = (PolicyError('input-invalid', 'Record operation failed; check the input and output files.')
                 if argv and argv[0] in ('bind', 'verify-delivery', 'prepare-selection', 'complete-selection',
                                         'launch-controls') else
                 PolicyError('discovery-unavailable', 'Discovery failed unexpectedly; rerun discover.'))
    sys.stderr.buffer.write(canonical(error.as_dict()) + b'\n')
    sys.stderr.flush()
    return 2


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
