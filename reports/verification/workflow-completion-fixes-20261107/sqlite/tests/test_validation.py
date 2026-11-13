import unittest
from email.message import Message

import validation as v


def headers(*pairs):
    result = Message()
    for key, value in pairs:
        result[key] = value
    return result


class ValidationTests(unittest.TestCase):
    def error(self, status, code, function, *args):
        with self.assertRaises(v.APIError) as caught:
            function(*args)
        self.assertEqual((caught.exception.status, caught.exception.code), (status, code))

    def test_title_trim_and_unicode_codepoints(self):
        for title in ['日本語', 'あ' * 200, 'あ' * 199 + '😀', '😀' * 200]:
            with self.subTest(length=len(title)):
                self.assertEqual(v.validate_title(' \t' + title + '\n'), title)
        for invalid in ['', ' \t\n', 'あ' * 200 + '😀', 1, True, None, [], '\ud800']:
            self.error(400, 'invalid_input', v.validate_title, invalid)

    def test_positive_ascii_decimal_ids(self):
        self.assertEqual(v.parse_id('123'), 123)
        for value in ['0', '-1', '+1', '1.0', 'true', '１', '١', '', '1/2', True, 1]:
            self.error(400, 'invalid_input', v.parse_id, value)
        self.assertEqual(v.parse_id('9' * 80), int('9' * 80))

    def test_origin_exact_host_and_port(self):
        for host in ['127.0.0.1:8123', 'localhost:8123']:
            v.validate_origin(headers(('Host', host)), 8123)
            v.validate_origin(headers(('Host', host), ('Origin', 'http://' + host)), 8123)
        for pairs in [[], [('Host', 'evil:8123')], [('Host', 'localhost')],
                      [('Host', 'localhost:8124')], [('Host', '127.0.0.1:8123.evil')],
                      [('Host', 'localhost:8123'), ('Origin', 'null')],
                      [('Host', 'localhost:8123'), ('Origin', 'http://127.0.0.1:8123')],
                      [('Host', 'localhost:8123'), ('Origin', 'https://localhost:8123')],
                      [('Host', 'localhost:8123'), ('Host', 'localhost:8123')],
                      [('Host', 'localhost:8123'), ('Origin', 'http://localhost:8123'), ('Origin', 'http://localhost:8123')]]:
            self.error(403, 'forbidden_origin', v.validate_origin, headers(*pairs), 8123)

    def test_length_and_framing(self):
        for size in [0, 1, 4096]:
            self.assertEqual(v.content_length(headers(('Content-Length', str(size)))), size)
        self.error(411, 'length_required', v.content_length, headers())
        for value in ['-1', '+1', '1.0', '1,1', '', '１', '1e2']:
            self.error(400, 'invalid_framing', v.content_length, headers(('Content-Length', value)))
        for pairs in [[('Content-Length', '0'), ('Content-Length', '0')],
                      [('Transfer-Encoding', 'identity')],
                      [('Content-Length', '4097'), ('Transfer-Encoding', 'chunked')]]:
            self.error(400, 'invalid_framing', v.content_length, headers(*pairs))
        for value in ['4097', '9' * 5000]:
            self.error(413, 'body_too_large', v.content_length, headers(('Content-Length', value)))

    def test_payload_types_fields_and_json(self):
        self.assertEqual(v.parse_payload(b'{"title":" hi "}', 'POST'), 'hi')
        for value in [b'true', b'false']:
            self.assertIs(v.parse_payload(b'{"completed":' + value + b'}', 'PATCH'), value == b'true')
        for raw in [b'', b'{', b'\xff', b'{"title": NaN}', b'{"title":"x"} {}']:
            self.error(400, 'invalid_json', v.parse_payload, raw, 'POST')
        for raw in [b'[]', b'null', b'"text"', b'{}', b'{"title":1}', b'{"title":"x","extra":1}', b'{"title":"x","title":"y"}']:
            self.error(400, 'invalid_input', v.parse_payload, raw, 'POST')
        for raw in [b'{"completed":0}', b'{"completed":1}', b'{"completed":"true"}', b'{"completed":null}', b'{"completed":true,"id":1}']:
            self.error(400, 'invalid_input', v.parse_payload, raw, 'PATCH')

    def test_media_and_compression(self):
        for value in ['application/json', 'application/json; charset=utf-8']:
            v.validate_media(headers(('Content-Type', value)), 'POST')
        v.validate_media(headers(), 'DELETE')
        for pairs, method in [([], 'POST'), ([('Content-Type', 'text/plain')], 'PATCH'),
                              ([('Content-Type', 'application/json'), ('Content-Encoding', 'gzip')], 'POST'),
                              ([('Content-Encoding', 'gzip')], 'DELETE')]:
            self.error(415, 'unsupported_media_type', v.validate_media, headers(*pairs), method)
