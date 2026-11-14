import http.client
import json
import select
import signal
import socket
import sqlite3
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

import app


class HTTPIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.db = Path(self.temporary.name) / 'tasks.sqlite3'
        self.processes = []
        self.addCleanup(self.stop_all)
        self.start()

    def start(self):
        command = [sys.executable, '-B', str(Path(app.__file__)), '--db', str(self.db), '--port', '0']
        process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        self.processes.append(process)
        assert process.stdout is not None
        self.assertTrue(select.select([process.stdout], [], [], 5)[0], 'startup output deadline')
        line = process.stdout.readline().strip()
        self.assertTrue(line.startswith('LISTENING http://127.0.0.1:'), line)
        self.port = int(line.rsplit(':', 1)[1])
        self.process = process
        print('PROCESS', json.dumps({'pid': process.pid, 'command': command, 'listen': line}), flush=True)

    def stop_all(self):
        for process in self.processes:
            if process.poll() is None:
                process.send_signal(signal.SIGINT)
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
            process.stdout.close()

    def request(self, method='GET', path='/api/tasks', body=None):
        connection = http.client.HTTPConnection('127.0.0.1', self.port, timeout=8)
        try:
            encoded = None if body is None else json.dumps(body, ensure_ascii=False).encode()
            headers = {} if encoded is None else {'Content-Type': 'application/json'}
            if method == 'DELETE':
                encoded = b''
            connection.request(method, path, encoded, headers)
            response = connection.getresponse()
            content = response.read()
            self.assertEqual(response.version, 10)
            self.assertEqual(response.getheader('Content-Length'), str(len(content)))
            self.assertEqual(response.getheader('Content-Type'), 'application/json; charset=utf-8')
            self.assertEqual(response.getheader('Connection'), 'close')
            self.assertIsNone(response.getheader('Access-Control-Allow-Origin'))
            return response.status, json.loads(content)
        finally:
            connection.close()

    def rows(self):
        status, body = self.request()
        self.assertEqual(status, 200)
        return body['tasks']

    def create(self, title):
        status, body = self.request('POST', body={'title': title})
        self.assertEqual(status, 201)
        self.assertIs(body['task']['completed'], False)
        return body['task']

    def raw(self, method, path, pairs, body=b'', shutdown=False):
        request = (method + ' ' + path + ' HTTP/1.1\r\n' + ''.join(k + ': ' + v + '\r\n' for k, v in pairs) + '\r\n').encode() + body
        started = time.monotonic()
        with socket.create_connection(('127.0.0.1', self.port), timeout=8) as sock:
            sock.sendall(request)
            if shutdown:
                sock.shutdown(socket.SHUT_WR)
            chunks = []
            while True:
                chunk = sock.recv(8192)
                if not chunk:
                    break
                chunks.append(chunk)
        head, content = b''.join(chunks).split(b'\r\n\r\n', 1)
        status = int(head.split()[1])
        self.assertIn(b'Content-Length: ' + str(len(content)).encode(), head)
        print('HTTP', json.dumps({'method': method, 'path': path, 'headers': pairs, 'sent_body_bytes': len(body), 'status': status, 'elapsed_s': round(time.monotonic() - started, 3)}), flush=True)
        return status, json.loads(content), time.monotonic() - started

    def base(self, size=None):
        result = [('Host', '127.0.0.1:' + str(self.port)), ('Content-Type', 'application/json')]
        if size is not None:
            result.append(('Content-Length', str(size)))
        return result

    def reject(self, status, code, method, path, pairs, body=b'', shutdown=False):
        before = self.rows()
        response = self.raw(method, path, pairs, body, shutdown)
        self.assertEqual(response[:2], (status, {'error': code}))
        self.assertEqual(self.rows(), before)
        print('UNCHANGED', json.dumps(before, ensure_ascii=False), flush=True)
        return response[2]

    def test_crud_and_real_process_restart(self):
        self.assertEqual(self.rows(), [])
        first = self.create('  日本語  ')
        second = self.create('日本語')
        third = self.create('削除')
        self.assertEqual(first['title'], '日本語')
        self.assertLess(first['id'], second['id'])
        path = '/api/tasks/' + str(second['id'])
        for completed in [True, False, True]:
            status, result = self.request('PATCH', path, {'completed': completed})
            self.assertEqual(status, 200)
            self.assertIs(result['task']['completed'], completed)
        self.assertEqual(self.request('DELETE', '/api/tasks/' + str(third['id'])), (200, {'deleted': third['id']}))
        expected = [first, dict(second, completed=True)]
        self.assertEqual(self.rows(), expected)
        old_pid = self.process.pid
        self.process.send_signal(signal.SIGINT)
        self.assertEqual(self.process.wait(timeout=3), 0)
        self.start()
        self.assertNotEqual(self.process.pid, old_pid)
        self.assertEqual(self.rows(), expected)
        print('RESTART', json.dumps({'old_pid': old_pid, 'new_pid': self.process.pid, 'same_db': str(self.db), 'rows': expected}, ensure_ascii=False), flush=True)

    def test_title_boundaries_and_literal_injection(self):
        for title in ['あ' * 200, 'あ' * 199 + '😀', '😀' * 200, '<img src=x onerror=alert(1)>', "'); DROP TABLE tasks; --"]:
            task = self.create(' \t' + title + '\n')
            self.assertEqual(task['title'], title)
            self.assertEqual(self.rows()[-1], task)
            print('TITLE', json.dumps({'codepoints': len(title), 'utf8_bytes': len(title.encode()), 'saved_exactly': True}), flush=True)
        for invalid in ['', ' \n', 'あ' * 200 + '😀', 1, True, None]:
            body = json.dumps({'title': invalid}, ensure_ascii=False).encode()
            self.reject(400, 'invalid_input', 'POST', '/api/tasks', self.base(len(body)), body)

    def test_raw_4096_4097_boundaries_literal_and_escaped(self):
        for escaped in [False, True]:
            payload = json.dumps({'title': '日本語😀'}, ensure_ascii=escaped).encode()
            body = payload + b' ' * (4096 - len(payload))
            before = self.rows()
            status, result, _ = self.raw('POST', '/api/tasks', self.base(4096), body)
            self.assertEqual(status, 201)
            self.assertEqual(result['task']['title'], '日本語😀')
            self.assertEqual(self.rows(), before + [result['task']])
            self.reject(413, 'body_too_large', 'POST', '/api/tasks', self.base(4097), body + b' ')
            path = '/api/tasks/' + str(result['task']['id'])
            patch = b'{"completed":true}'
            padded = patch + b' ' * (4096 - len(patch))
            self.assertEqual(self.raw('PATCH', path, self.base(4096), padded)[0], 200)
            self.assertIs(self.rows()[-1]['completed'], True)
            self.reject(413, 'body_too_large', 'PATCH', path, self.base(4097), padded + b' ')
        for method, path in [('POST', '/api/tasks'), ('PATCH', '/api/tasks/1'), ('DELETE', '/api/tasks/1')]:
            elapsed = self.reject(413, 'body_too_large', method, path, self.base(4097))
            self.assertLess(elapsed, 2, 'oversize must reject before waiting for withheld body')

    def test_framing_negatives_and_read_timeout(self):
        self.create('保護')
        self.reject(411, 'length_required', 'POST', '/api/tasks', self.base())
        for value in ['-1', 'abc', '+1', '1.0', '1,1']:
            self.reject(400, 'invalid_framing', 'POST', '/api/tasks', self.base() + [('Content-Length', value)])
        for pairs in [self.base(0) + [('Content-Length', '0')], self.base(0) + [('Transfer-Encoding', 'chunked')], self.base() + [('Transfer-Encoding', 'identity')]]:
            self.reject(400, 'invalid_framing', 'POST', '/api/tasks', pairs)
        self.reject(400, 'invalid_framing', 'POST', '/api/tasks', self.base(30), b'{}', shutdown=True)
        elapsed = self.reject(400, 'invalid_framing', 'POST', '/api/tasks', self.base(30), b'{}')
        self.assertGreaterEqual(elapsed, 4.5)
        self.assertLess(elapsed, 7)
        self.reject(400, 'invalid_input', 'DELETE', '/api/tasks/1', self.base(2), b'{}')

    def test_origin_json_media_route_and_method_errors(self):
        self.create('保存')
        body = b'{"title":"x"}'
        for host, origin in [('evil.test', None), ('localhost', None), ('127.0.0.1:' + str(self.port), 'null'), ('127.0.0.1:' + str(self.port), 'http://evil.test')]:
            pairs = [('Host', host), ('Content-Length', str(len(body))), ('Content-Type', 'application/json')]
            if origin is not None:
                pairs.append(('Origin', origin))
            self.reject(403, 'forbidden_origin', 'POST', '/api/tasks', pairs, body)
        for content in [b'{', b'\xff', b'{"title":NaN}']:
            self.reject(400, 'invalid_json', 'POST', '/api/tasks', self.base(len(content)), content)
        for content in [b'[]', b'{}', b'{"title":true}', b'{"title":"x","extra":1}']:
            self.reject(400, 'invalid_input', 'POST', '/api/tasks', self.base(len(content)), content)
        for content in [b'{"completed":1}', b'{"completed":0}', b'{"completed":"true"}', b'{"completed":null}']:
            self.reject(400, 'invalid_input', 'PATCH', '/api/tasks/1', self.base(len(content)), content)
        pairs = [('Host', 'localhost:' + str(self.port)), ('Content-Length', str(len(body))), ('Content-Type', 'text/plain')]
        self.reject(415, 'unsupported_media_type', 'POST', '/api/tasks', pairs, body)
        self.reject(415, 'unsupported_media_type', 'POST', '/api/tasks', self.base(len(body)) + [('Content-Encoding', 'gzip')], body)
        for identifier in ['0', '-1', 'true', '+1', '1.2', '%31']:
            self.reject(400, 'invalid_input', 'DELETE', '/api/tasks/' + identifier, self.base(0))
        for identifier in ['999999', '9' * 80]:
            self.reject(404, 'not_found', 'DELETE', '/api/tasks/' + identifier, self.base(0))
        for path in ['/missing', '/repository.py', '/data/tasks.sqlite3', '/design-system/design-tokens.json', '/../app.py', '/%2e%2e/app.py', '/api/tasks/1/extra']:
            self.reject(404, 'not_found', 'GET', path, self.base())
        for method in ['PUT', 'OPTIONS', 'TRACE', 'BREW']:
            self.reject(405, 'method_not_allowed', method, '/api/tasks', self.base(0))
        self.reject(405, 'method_not_allowed', 'GET', '/api/tasks/1', self.base())
        self.reject(405, 'method_not_allowed', 'POST', '/app.js', self.base(0))

    def test_locked_storage_error_rollback_and_recovery(self):
        self.create('保存')
        before = self.rows()
        connection = sqlite3.connect(self.db)
        try:
            connection.execute('BEGIN EXCLUSIVE')
            self.assertEqual(self.request('POST', body={'title': '失敗'}), (500, {'error': 'storage_error'}))
        finally:
            connection.rollback()
            connection.close()
        self.assertEqual(self.rows(), before)
        self.create('復旧')

    def test_concurrent_admission_timeout_and_recovery(self):
        sockets = []
        try:
            for _ in range(8):
                sock = socket.create_connection(('127.0.0.1', self.port), timeout=8)
                sock.sendall(('POST /api/tasks HTTP/1.1\r\nHost: localhost:' + str(self.port) + '\r\nContent-Type: application/json\r\nContent-Length: 20\r\n\r\n').encode())
                sockets.append(sock)
            time.sleep(0.15)
            with socket.create_connection(('127.0.0.1', self.port), timeout=1) as excess:
                try:
                    self.assertEqual(excess.recv(1), b'')
                except ConnectionResetError:
                    pass
            for sock in sockets:
                response = sock.recv(4096)
                self.assertIn(b'400', response.split(b'\r\n')[0])
        finally:
            for sock in sockets:
                sock.close()
        self.assertEqual(self.rows(), [])
        self.create('recovered')

    def test_bad_existing_database_startup_preserves_bytes_and_does_not_bind(self):
        self.process.send_signal(signal.SIGINT)
        self.process.wait(timeout=3)
        bad = Path(self.temporary.name) / 'bad.sqlite3'
        bad.write_bytes(b'not a sqlite database')
        before = bad.read_bytes()
        with socket.socket() as reserved:
            reserved.bind(('127.0.0.1', 0))
            port = reserved.getsockname()[1]
        result = subprocess.run([sys.executable, '-B', str(Path(app.__file__)), '--db', str(bad), '--port', str(port)], check=False, capture_output=True, timeout=5)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'database', result.stderr.lower())
        self.assertNotIn(b'LISTENING', result.stdout)
        self.assertEqual(bad.read_bytes(), before)
        with socket.socket() as check:
            check.bind(('127.0.0.1', port))


if __name__ == '__main__':
    unittest.main()
