import io
import json
import socket
import sqlite3
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from typing import cast
from unittest.mock import Mock, patch

import app


class Input(io.BytesIO):
    def __init__(self, data, timeout=False):
        super().__init__(data)
        self.read_sizes = []
        self.timeout = timeout

    def read(self, size=-1):
        self.read_sizes.append(size)
        if self.timeout:
            raise TimeoutError('body timed out')
        return super().read(size)

    def close(self):
        pass


class FakeSocket:
    def __init__(self, data, timeout=False):
        self.stream = Input(data, timeout)
        self.output = io.BytesIO()
        self.timeouts = []

    def settimeout(self, value):
        self.timeouts.append(value)

    def makefile(self, *args, **kwargs):
        return self.stream

    def sendall(self, data):
        self.output.write(data)


class HandlerTests(unittest.TestCase):
    def request(self, method='POST', path='/api/tasks', body=b'{"title":"x"}', extra=None, timeout=False):
        pairs = [('Host', 'localhost:8123'), ('Content-Type', 'application/json'), ('Content-Length', str(len(body)))]
        if extra is not None:
            pairs = extra
        raw = (method + ' ' + path + ' HTTP/1.1\r\n' + ''.join(k + ': ' + v + '\r\n' for k, v in pairs) + '\r\n').encode() + body
        sock = FakeSocket(raw, timeout)
        server = SimpleNamespace(server_port=8123, db_path='unused')
        handler = app.TaskHandler(cast(socket.socket, sock), ('127.0.0.1', 1), cast(app.BoundedHTTPServer, server))
        head, content = sock.output.getvalue().split(b'\r\n\r\n', 1)
        self.assertIn(b'Content-Length: ' + str(len(content)).encode(), head)
        self.assertIn(b'Connection: close', head)
        self.assertTrue(handler.close_connection)
        self.assertEqual(sock.timeouts, [5])
        return int(head.split()[1]), json.loads(content), sock

    def test_sql_integer_serializes_as_json_bool(self):
        for value in [0, 1]:
            row = {'id': 1, 'title': '日本語', 'completed': value}
            dto = app.task_dto(row)
            self.assertEqual(set(dto), {'id', 'title', 'completed'})
            self.assertIs(dto['completed'], bool(value))

    def test_oversize_before_read_even_wrong_media_and_delete(self):
        for method in ['POST', 'PATCH', 'DELETE']:
            with patch.object(app.repository, 'create_task') as create, patch.object(app.repository, 'set_completed') as toggle, patch.object(app.repository, 'delete_task') as delete:
                status, data, sock = self.request(method, '/api/tasks/1' if method != 'POST' else '/api/tasks', b'', [('Host', 'localhost:8123'), ('Content-Length', '4097')])
                self.assertEqual((status, data), (413, {'error': 'body_too_large'}))
                self.assertEqual(sock.stream.read_sizes, [])
                create.assert_not_called()
                toggle.assert_not_called()
                delete.assert_not_called()

    def test_truncated_and_timeout_bodies_do_not_mutate(self):
        for timeout in [False, True]:
            with patch.object(app.repository, 'create_task') as create:
                status, data, sock = self.request(body=b'{}', extra=[('Host', 'localhost:8123'), ('Content-Type', 'application/json'), ('Content-Length', '100')], timeout=timeout)
                self.assertEqual((status, data), (400, {'error': 'invalid_framing'}))
                self.assertEqual(sock.stream.read_sizes, [100])
                create.assert_not_called()

    def test_invalid_input_never_reaches_repository(self):
        for body in [b'{}', b'[]', b'{"title":" "}', b'{"title":true}', b'{"title":"x","admin":true}']:
            with patch.object(app.repository, 'create_task') as create:
                self.assertEqual(self.request(body=body)[0], 400)
                create.assert_not_called()

    def test_status_dto_and_storage_error_normalization(self):
        row = {'id': 7, 'title': 'x', 'completed': 0}
        with patch.object(app.repository, 'create_task', return_value=row) as create:
            self.assertEqual(self.request()[:2], (201, {'task': {'id': 7, 'title': 'x', 'completed': False}}))
            create.assert_called_once_with('unused', 'x')
        for method, path, body, function in [('GET', '/api/tasks', b'', 'list_tasks'), ('POST', '/api/tasks', b'{"title":"x"}', 'create_task'), ('PATCH', '/api/tasks/1', b'{"completed":true}', 'set_completed'), ('DELETE', '/api/tasks/1', b'', 'delete_task')]:
            with patch.object(app.repository, function, side_effect=sqlite3.OperationalError('private path')):
                self.assertEqual(self.request(method, path, body)[:2], (500, {'error': 'storage_error'}))

    def test_static_allowlist_maps_fixed_files_only(self):
        expected = {'/': 'static/index.html', '/app.js': 'static/app.js', '/styles.css': 'static/styles.css', '/tokens.css': 'design-system/build/tokens.css'}
        self.assertEqual({key: str(path.relative_to(app.ROOT)) for key, path in app.STATIC_FILES.items()}, expected)
        for path in ['/../repository.py', '/data/tasks.sqlite3', '/schema.py', '/%2e%2e/app.py']:
            self.assertEqual(self.request('GET', path, b'')[0], 404)

    def test_startup_initializes_before_server_constructor(self):
        calls = []

        def bind(*args):
            calls.append('bind')
            return Mock()

        with patch.object(app.schema, 'initialize_database', side_effect=lambda db: calls.append('schema')), patch.object(app, 'BoundedHTTPServer', side_effect=bind):
            app.create_server('test.db', 8000)
        self.assertEqual(calls, ['schema', 'bind'])
        with patch.object(app.schema, 'initialize_database', side_effect=app.schema.SchemaError('bad')), patch.object(app, 'BoundedHTTPServer') as server:
            with self.assertRaises(app.schema.SchemaError):
                app.create_server('test.db', 8000)
            server.assert_not_called()

    def test_handler_admission_and_cleanup(self):
        with tempfile.TemporaryDirectory() as directory:
            server = app.create_server(Path(directory) / 'tasks.db', 0)
            try:
                self.assertEqual(server.server_address[0], '127.0.0.1')
                self.assertEqual(server.request_queue_size, 8)
                self.assertTrue(server.daemon_threads)
                for _ in range(8):
                    self.assertTrue(server.slots.acquire(blocking=False))
                self.assertFalse(server.slots.acquire(blocking=False))
                with patch.object(server, 'shutdown_request') as close:
                    server.process_request(Mock(), ('127.0.0.1', 1))
                    close.assert_called_once()
                with patch.object(server, 'finish_request', side_effect=RuntimeError('handler')), patch.object(server, 'handle_error'), patch.object(server, 'shutdown_request') as close:
                    server.process_request_thread(Mock(), ('127.0.0.1', 1))
                    close.assert_called_once()
                self.assertTrue(server.slots.acquire(blocking=False))
                for _ in range(8):
                    server.slots.release()
            finally:
                server.server_close()
