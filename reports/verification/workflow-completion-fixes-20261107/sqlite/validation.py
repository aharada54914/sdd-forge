"""Pure validation of the local task API's untrusted request boundary."""

import json
import re


class APIError(Exception):
    def __init__(self, status, code):
        super().__init__(code)
        self.status = status
        self.code = code


def validate_title(value):
    if not isinstance(value, str):
        raise APIError(400, 'invalid_input')
    title = value.strip()
    if not 1 <= len(title) <= 200 or any(0xD800 <= ord(char) <= 0xDFFF for char in title):
        raise APIError(400, 'invalid_input')
    return title


def parse_id(value):
    if not isinstance(value, str) or re.fullmatch(r'[0-9]+', value) is None:
        raise APIError(400, 'invalid_input')
    # Chunk conversion also handles very long decimal IDs without Python's
    # decimal-string conversion limit. The HTTP layer treats out-of-range IDs
    # as nonexistent, rather than passing an overflowing integer to SQLite.
    result = 0
    for start in range(0, len(value), 1000):
        chunk = value[start:start + 1000]
        result = result * 10 ** len(chunk) + int(chunk)
    if result <= 0:
        raise APIError(400, 'invalid_input')
    return result


def validate_origin(headers, port):
    hosts = headers.get_all('Host', [])
    origins = headers.get_all('Origin', [])
    if len(hosts) != 1 or hosts[0] not in {f'127.0.0.1:{port}', f'localhost:{port}'}:
        raise APIError(403, 'forbidden_origin')
    if origins and (len(origins) != 1 or origins[0] != 'http://' + hosts[0]):
        raise APIError(403, 'forbidden_origin')


def content_length(headers):
    lengths = headers.get_all('Content-Length', [])
    if headers.get_all('Transfer-Encoding') or len(lengths) > 1:
        raise APIError(400, 'invalid_framing')
    if not lengths:
        raise APIError(411, 'length_required')
    value = lengths[0]
    if re.fullmatch(r'[0-9]+', value) is None:
        raise APIError(400, 'invalid_framing')
    significant = value.lstrip('0') or '0'
    if len(significant) > 4 or (len(significant) == 4 and significant > '4096'):
        raise APIError(413, 'body_too_large')
    return int(significant)


def validate_media(headers, method):
    if headers.get_all('Content-Encoding'):
        raise APIError(415, 'unsupported_media_type')
    if method in {'POST', 'PATCH'}:
        types = headers.get_all('Content-Type', [])
        if len(types) != 1 or types[0].split(';', 1)[0].strip().lower() != 'application/json':
            raise APIError(415, 'unsupported_media_type')


def _object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise APIError(400, 'invalid_input')
        result[key] = value
    return result


def _invalid_constant(value):
    raise ValueError('JSON constants must be finite')


def parse_payload(raw, method):
    try:
        value = json.loads(raw.decode('utf-8'), object_pairs_hook=_object, parse_constant=_invalid_constant)
    except (UnicodeDecodeError, ValueError, RecursionError):
        raise APIError(400, 'invalid_json') from None
    field = 'title' if method == 'POST' else 'completed'
    if not isinstance(value, dict) or set(value) != {field}:
        raise APIError(400, 'invalid_input')
    if method == 'POST':
        return validate_title(value[field])
    if type(value[field]) is not bool:
        raise APIError(400, 'invalid_input')
    return value[field]
