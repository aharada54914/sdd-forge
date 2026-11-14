"""Contract HTTP tests using real sockets and temporary JSON, never UI fixtures."""
from __future__ import annotations

from contextlib import redirect_stderr
import http.client
import io
import json
from pathlib import Path
import re
import select
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
from typing import Any
import unittest
from unittest.mock import patch
from uuid import UUID, uuid4

import server


class HTTPTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.data = self.root / 'data' / 'tasks.json'
        (self.root / 'web').mkdir()
        (self.root / 'design-system' / 'build').mkdir(parents=True)
        self.assets = {
            '/': ('web/index.html', '<h1>合成テスト</h1>', 'text/html'),
            '/app.js': ('web/app.js', '"use strict";', 'text/javascript'),
            '/styles.css': ('web/styles.css', 'body {}', 'text/css'),
            '/tokens.css': ('design-system/build/tokens.css', ':root {}', 'text/css'),
        }
        for name, content, _ in self.assets.values():
            (self.root / name).write_text(content, encoding='utf-8')
        self.logs = io.StringIO()
        self.log_context = redirect_stderr(self.logs)
        self.log_context.__enter__()
        self.addCleanup(self.log_context.__exit__, None, None, None)
        self.start()
        self.addCleanup(self.stop)

    def start(self) -> None:
        self.httpd = server.create_server(self.data, port=0, static_root=self.root)
        self.port = self.httpd.server_port
        self.thread = threading.Thread(target=self.httpd.serve_forever,
                                       kwargs={'poll_interval': 0.01})
        self.thread.start()

    def stop(self) -> None:
        self.httpd.shutdown()
        self.httpd.server_close()
        self.thread.join(timeout=5)
        self.assertFalse(self.thread.is_alive())

    def request(self, method: str, path: str = '/api/tasks', body: bytes | None = None,
                headers: dict[str, str] | None = None) -> tuple[int, dict[str, str], bytes]:
        connection = http.client.HTTPConnection('127.0.0.1', self.port, timeout=3)
        try:
            connection.request(method, path, body=body, headers=headers or {})
            response = connection.getresponse()
            content = response.read()
            values = {key.lower(): value for key, value in response.getheaders()}
            self.assertEqual(int(values['content-length']), len(content))
            self.assertNotIn('access-control-allow-origin', values)
            return response.status, values, content
        finally:
            connection.close()

    def api(self, method: str, path: str = '/api/tasks', payload: object = None,
            expected: int = 200) -> dict[str, Any]:
        body = None if payload is None else json.dumps(payload, ensure_ascii=False).encode()
        status, headers, content = self.request(method, path, body,
                                               {'Content-Type': 'application/json'})
        self.assertEqual(status, expected, content)
        self.assertEqual(headers['content-type'], 'application/json; charset=utf-8')
        self.assertEqual(headers['cache-control'], 'no-store')
        document: dict[str, Any] = json.loads(content)
        self.assertIsInstance(document, dict)
        self.assertEqual(set(document), {'tasks'} if expected < 400 else {'error'})
        return document

    def seed(self) -> str:
        document = self.api('POST', payload={'title': '保持するタスク'}, expected=201)
        return str(document['tasks'][0]['id'])

    def assert_rejected(self, method: str, path: str, body: bytes | None,
                        expected: int, headers: dict[str, str] | None = None) -> None:
        before = self.data.read_bytes()
        status, values, content = self.request(method, path, body, headers or {
            'Content-Type': 'application/json',
        })
        self.assertEqual(status, expected, content)
        self.assertEqual(set(json.loads(content)), {'error'})
        self.assertEqual(values['content-type'], 'application/json; charset=utf-8')
        self.assertEqual(values['cache-control'], 'no-store')
        self.assertTrue(any(ord(char) > 127 for char in json.loads(content)['error']))
        self.assertEqual(self.data.read_bytes(), before)

    def raw(self, method: str, path: str, headers: list[tuple[str, str]],
            body: bytes = b'') -> tuple[int, dict[str, str], bytes]:
        wire = (f'{method} {path} HTTP/1.1\r\n' +
                ''.join(f'{key}: {value}\r\n' for key, value in headers) + '\r\n').encode()
        with socket.create_connection(('127.0.0.1', self.port), timeout=3) as client:
            client.sendall(wire + body)
            client.shutdown(socket.SHUT_WR)
            response = http.client.HTTPResponse(client, method=method)
            response.begin()
            content = response.read()
            values = {key.lower(): value for key, value in response.getheaders()}
            return response.status, values, content

    def test_crud_snapshots_unicode_order_and_restart(self) -> None:
        self.assertEqual(self.api('GET'), {'tasks': []})
        self.assertFalse(self.data.exists())
        title = '買い物 <script>alert(1)</script> 😀'
        first = self.api('POST', payload={'title': f' \u3000{title}\n'}, expected=201)
        task = first['tasks'][0]
        self.assertEqual(set(task), {'id', 'title', 'completed'})
        UUID(task['id'])
        self.assertEqual(task['title'], title)
        self.assertIs(task['completed'], False)
        second = self.api('POST', payload={'title': '次のタスク'}, expected=201)
        self.assertEqual(second['tasks'][0], task)
        path = '/api/tasks/' + task['id']
        for completed in (True, True, False):
            changed = self.api('PATCH', path, {'completed': completed})
            self.assertIs(changed['tasks'][0]['completed'], completed)
            self.assertEqual(json.loads(self.data.read_text())['tasks'], changed['tasks'])
            self.stop()
            self.start()
            self.assertEqual(self.api('GET'), changed)
        deleted = self.api('DELETE', path)
        self.assertEqual(deleted['tasks'], second['tasks'][1:])
        self.stop()
        self.start()
        self.assertEqual(self.api('GET'), deleted)
        self.assertNotIn(title, self.logs.getvalue())

    def test_titles_schema_and_scalar_types(self) -> None:
        task_id = self.seed()
        title: object
        payload: object
        for title in ('', ' ', '\u3000', '\n\t', 'a' * 501, '😀' * 501,
                      None, False, 12, [], {}, '\ud800'):
            with self.subTest(title=repr(title)):
                self.assert_rejected('POST', '/api/tasks', json.dumps({'title': title}).encode(), 400)
        for payload in ({}, {'title': 'ok', 'other': 1}, {'completed': False},
                        [], None, 'text', True, 1):
            with self.subTest(payload=payload):
                self.assert_rejected('POST', '/api/tasks', json.dumps(payload).encode(), 400)
        for payload in ({}, {'completed': False, 'title': 'x'}, {'completed': 0},
                        {'completed': 1}, {'completed': 'false'}, {'completed': None},
                        {'completed': []}, {'completed': {}}, []):
            with self.subTest(payload=payload):
                self.assert_rejected('PATCH', '/api/tasks/' + task_id,
                                     json.dumps(payload).encode(), 400)
        for title in ('x', '😀' * 500):
            document = self.api('POST', payload={'title': title}, expected=201)
            self.assertEqual(document['tasks'][-1]['title'], title)

    def test_json_syntax_duplicates_encoding_and_nesting(self) -> None:
        self.seed()
        for body in (b'', b'{', b'{}x', b'\xff', b'{"title":"x","title":"y"}',
                     b'{"title":NaN}', b'{"title":Infinity}', b'{"title":-Infinity}',
                     b'[' * 2000 + b']' * 2000,
                     b'{"title":{"nested":1,"nested":2}}'):
            with self.subTest(body=body[:80]):
                self.assert_rejected('POST', '/api/tasks', body, 400)

    def test_uuid_and_route_contract(self) -> None:
        self.seed()
        for method, body in [('PATCH', b'{"completed":true}'), ('DELETE', None)]:
            for identity, status in [('not-a-uuid', 400), (str(uuid4()), 404)]:
                self.assert_rejected(method, '/api/tasks/' + identity, body, status)
        for method, path, body, status in (
            ('GET', '/api/unknown', None, 404),
            ('POST', '/api/unknown', b'{"title":"x"}', 404),
            ('PATCH', '/api/tasks', b'{"completed":true}', 405),
            ('DELETE', '/api/tasks', None, 405),
            ('POST', '/api/tasks/' + str(uuid4()), b'{"title":"x"}', 405),
            ('GET', '/api/tasks/' + str(uuid4()), None, 405),
            ('POST', '/', b'{"title":"x"}', 405),
            ('PUT', '/api/tasks', b'{}', 405),
            ('OPTIONS', '/api/tasks', None, 405),
            ('TRACE', '/api/tasks', None, 405),
            ('BREW', '/api/tasks', None, 405),
        ):
            with self.subTest(method=method, path=path):
                self.assert_rejected(method, path, body, status)
        # HEAD has no response body under HTTP semantics, including its 405.
        status, _, content = self.raw('HEAD', '/api/tasks', [('Host', f'127.0.0.1:{self.port}')])
        self.assertEqual(status, 405)
        self.assertEqual(content, b'')

    def test_content_type_size_and_bodyless_methods(self) -> None:
        task_id = self.seed()
        for value in ('text/plain', 'application/x-www-form-urlencoded',
                      'application/json; charset=latin-1', 'application/json; bogus=yes'):
            self.assert_rejected('POST', '/api/tasks', b'{"title":"x"}', 415,
                                 {'Content-Type': value})
        self.assert_rejected('POST', '/api/tasks', b'{"title":"x"}', 415, {'X-Test': 'yes'})
        self.assert_rejected('POST', '/api/tasks', b'x' * 65537, 413)
        accepted = b'{"title":"boundary"}'
        status, _, _ = self.request('POST', '/api/tasks', accepted.ljust(65536, b' '),
                                    {'Content-Type': 'application/json; charset=utf-8'})
        self.assertEqual(status, 201)
        for method, path in [('GET', '/api/tasks'), ('DELETE', '/api/tasks/' + task_id)]:
            self.assert_rejected(method, path, b'{}', 400)

    def test_bad_framing_is_closed_without_mutation(self) -> None:
        self.seed()
        base = [('Host', f'127.0.0.1:{self.port}'), ('Content-Type', 'application/json')]
        variants = [[], [('Content-Length', '-1')], [('Content-Length', '+2')],
                    [('Content-Length', '-0')], [('Content-Length', 'x')],
                    [('Content-Length', '2.0')], [('Content-Length', '')],
                    [('Content-Length', '2'), ('Content-Length', '2')],
                    [('Content-Length', '2, 2')], [('Content-Length', '65537')],
                    [('Content-Length', '9' * 5000)],
                    [('Transfer-Encoding', 'chunked')],
                    [('Transfer-Encoding', 'identity'), ('Content-Length', '2')],
                    [('Content-Length', '50')]]
        for headers in variants:
            with self.subTest(headers=headers):
                before = self.data.read_bytes()
                status, values, content = self.raw('POST', '/api/tasks', base + headers, b'{}')
                expected = 413 if headers and headers[0][1] in ('65537', '9' * 5000) else 400
                self.assertEqual(status, expected, content)
                self.assertEqual(set(json.loads(content)), {'error'})
                self.assertEqual(values['connection'].lower(), 'close')
                self.assertEqual(self.data.read_bytes(), before)

    def test_host_and_origin_allowlists(self) -> None:
        task_id = self.seed()
        for host in ('example.com', 'localhost', '127.0.0.1', f'127.0.0.1:{self.port + 1}',
                     f'localhost:{self.port}.evil.test', f'[::1]:{self.port}'):
            for method, path, body in [('GET', '/api/tasks', None),
                                       ('POST', '/api/tasks', b'{"title":"x"}')]:
                self.assert_rejected(method, path, body, 403,
                                     {'Host': host, 'Content-Type': 'application/json'})
        for origin in ('null', 'https://127.0.0.1:' + str(self.port), 'http://evil.test',
                       f'http://localhost:{self.port}/', f'http://localhost:{self.port + 1}'):
            for method, path, body in [('POST', '/api/tasks', b'{"title":"x"}'),
                                       ('PATCH', '/api/tasks/' + task_id, b'{"completed":true}'),
                                       ('DELETE', '/api/tasks/' + task_id, None)]:
                self.assert_rejected(method, path, body, 403,
                                     {'Origin': origin, 'Content-Type': 'application/json'})
        for host in ('localhost', '127.0.0.1'):
            status, _, _ = self.request('POST', body=b'{"title":"allowed"}', headers={
                'Host': f'{host}:{self.port}', 'Origin': f'http://{host}:{self.port}',
                'Content-Type': 'application/json',
            })
            self.assertEqual(status, 201)
        for headers in ([], [('Host', f'localhost:{self.port}')] * 2,
                        [('Host', f'localhost:{self.port}'), ('Origin', 'null'),
                         ('Origin', f'http://localhost:{self.port}')]):
            before = self.data.read_bytes()
            status, _, _ = self.raw('DELETE', '/api/tasks/' + task_id, headers)
            self.assertEqual(status, 403)
            self.assertEqual(self.data.read_bytes(), before)

    def test_static_exact_allowlist_and_loopback(self) -> None:
        self.seed()
        self.assertEqual(self.httpd.socket.getsockname()[0], '127.0.0.1')
        for route, (_, expected, mime) in self.assets.items():
            status, headers, content = self.request('GET', route)
            self.assertEqual(status, 200)
            self.assertEqual(headers['content-type'], mime + '; charset=utf-8')
            self.assertEqual(content.decode(), expected)
        for path in ('/data/tasks.json', '/store.py', '/specs/task-board/design.md',
                     '/web/index.html', '/web/', '/..%2fdata/tasks.json', '/%2e%2e/data/tasks.json',
                     '/%252e%252e/data/tasks.json', '//data/tasks.json', '/tokens.css/../data/tasks.json',
                     '/app.js/extra', '/%00', '/%ff'):
            with self.subTest(path=path):
                self.assert_rejected('GET', path, None, 404)
        (self.root / 'web' / 'app.js').unlink()
        (self.root / 'web' / 'app.js').symlink_to(self.data)
        self.assert_rejected('GET', '/app.js', None, 404)

    def test_storage_failure_and_corruption_keep_bytes_and_recover(self) -> None:
        task_id = self.seed()
        before = self.data.read_bytes()
        with patch('store.os.replace', side_effect=OSError('/private/path SECRET_TITLE')):
            for method, path, body in [('POST', '/api/tasks', b'{"title":"x"}'),
                                       ('PATCH', '/api/tasks/' + task_id, b'{"completed":true}'),
                                       ('DELETE', '/api/tasks/' + task_id, None)]:
                self.assert_rejected(method, path, body, 500)
        self.assertEqual(list(self.data.parent.glob('.tasks-*.tmp')), [])
        self.assertNotIn('/private/path', self.logs.getvalue())
        self.assertNotIn('SECRET_TITLE', self.logs.getvalue())
        self.assertIn('StorageError', self.logs.getvalue())
        self.data.write_bytes(b'{broken-preserve-me')
        for method, path, body in [('GET', '/api/tasks', None),
                                   ('POST', '/api/tasks', b'{"title":"x"}'),
                                   ('PATCH', '/api/tasks/' + task_id, b'{"completed":true}'),
                                   ('DELETE', '/api/tasks/' + task_id, None)]:
            self.assert_rejected(method, path, body, 500)
        self.data.write_bytes(before)
        self.assertEqual(self.api('GET')['tasks'][0]['id'], task_id)
        self.api('POST', payload={'title': '回復'}, expected=201)


class CLITests(unittest.TestCase):
    def test_cli_restart_and_source_restore_preserve_json(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = Path(server.__file__).resolve()
            saved_source = source.read_bytes()
            shutil.copyfile(source, root / 'server.py')
            shutil.copyfile(source.with_name('store.py'), root / 'store.py')
            data = root / 'data' / 'tasks.json'

            def start() -> tuple[subprocess.Popen[str], int]:
                process = subprocess.Popen([sys.executable, str(root / 'server.py'),
                                            '--port', '0', '--data-file', str(data)],
                                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
                self.addCleanup(self.stop_process, process)
                assert process.stdout is not None
                ready, _, _ = select.select([process.stdout], [], [], 5)
                self.assertTrue(ready, 'CLI did not announce its bound URL')
                line = process.stdout.readline()
                match = re.search(r'http://127\.0\.0\.1:(\d+)', line)
                self.assertIsNotNone(match, line)
                assert match is not None
                return process, int(match[1])

            first, port = start()
            connection = http.client.HTTPConnection('127.0.0.1', port, timeout=3)
            connection.request('POST', '/api/tasks', body='{"title":"restart"}',
                               headers={'Content-Type': 'application/json'})
            response = connection.getresponse()
            self.assertEqual(response.status, 201)
            expected = response.read()
            connection.close()
            self.stop_process(first)
            before = data.read_bytes()
            # Drill source rollback in this test's isolated copy, never the working tree.
            (root / 'server.py').write_text('raise RuntimeError("synthetic bad release")\n')
            (root / 'server.py').write_bytes(saved_source)
            second, port = start()
            connection = http.client.HTTPConnection('127.0.0.1', port, timeout=3)
            connection.request('GET', '/api/tasks')
            response = connection.getresponse()
            self.assertEqual(response.status, 200)
            self.assertEqual(response.read(), expected)
            connection.close()
            self.stop_process(second)
            self.assertEqual(data.read_bytes(), before)
            self.assertEqual((root / 'server.py').read_bytes(), saved_source)

    @staticmethod
    def stop_process(process: subprocess.Popen[str]) -> None:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=5)
        if process.stdout is not None:
            process.stdout.close()
        if process.stderr is not None:
            process.stderr.close()


if __name__ == '__main__':
    unittest.main()
