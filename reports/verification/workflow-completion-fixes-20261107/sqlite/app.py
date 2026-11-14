"""Loopback-only task API. Run: python3 app.py --db data/tasks.sqlite3 --port 8000."""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import repository
import schema
import validation
from validation import APIError

ROOT = Path(__file__).resolve().parent
STATIC_FILES = {
    '/': ROOT / 'static/index.html',
    '/app.js': ROOT / 'static/app.js',
    '/styles.css': ROOT / 'static/styles.css',
    '/tokens.css': ROOT / 'design-system/build/tokens.css',
}


def task_dto(row):
    return {'id': row['id'], 'title': row['title'], 'completed': bool(row['completed'])}


class TaskHandler(BaseHTTPRequestHandler):
    server: BoundedHTTPServer
    protocol_version = 'HTTP/1.0'
    timeout = 5

    def __getattr__(self, name):
        # Route every parsed HTTP method through the same JSON error boundary,
        # including unrecognized tokens that BaseHTTPRequestHandler calls do_*.
        if name.startswith('do_'):
            return self.dispatch
        raise AttributeError(name)

    def log_request(self, code='-', size='-'):
        # Status only: neither titles, request bodies nor arbitrary URL text.
        self.log_message('status=%s', code)

    def send_bytes(self, status, content, content_type):
        self.close_connection = True
        self.send_response(status)
        self.send_header('Content-Type', content_type)
        self.send_header('Content-Length', str(len(content)))
        self.send_header('Connection', 'close')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.end_headers()
        if self.command != 'HEAD':
            self.wfile.write(content)

    def send_json(self, status, value):
        self.send_bytes(status, json.dumps(value, ensure_ascii=False, separators=(',', ':')).encode('utf-8'), 'application/json; charset=utf-8')

    def send_error(self, code, message=None, explain=None):
        # Base parser failures must not leak HTML or parser/internal details.
        self.send_json(400, {'error': 'invalid_framing'})

    def dispatch(self):
        try:
            validation.validate_origin(self.headers, self.server.server_port)
            self.route()
        except APIError as error:
            self.send_json(error.status, {'error': error.code})
        except sqlite3.Error:
            self.send_json(500, {'error': 'storage_error'})
        except (BrokenPipeError, ConnectionResetError):
            # A disconnected client cannot receive an acknowledgment. Never
            # retry its mutation; any already committed transaction is durable.
            self.close_connection = True

    def mutation_body(self):
        length = validation.content_length(self.headers)
        validation.validate_media(self.headers, self.command)
        try:
            body = self.rfile.read(length)
        except (TimeoutError, OSError):
            raise APIError(400, 'invalid_framing') from None
        if len(body) != length:
            raise APIError(400, 'invalid_framing')
        if self.command == 'DELETE':
            if body:
                raise APIError(400, 'invalid_input')
            return None
        return validation.parse_payload(body, self.command)

    def route(self):
        path = self.path
        method = self.command
        collection = path == '/api/tasks'
        item = path.startswith('/api/tasks/') and '/' not in path[len('/api/tasks/'):]
        static = path in STATIC_FILES
        if not (collection or item or static):
            raise APIError(404, 'not_found')
        allowed = {'GET', 'POST'} if collection else {'PATCH', 'DELETE'} if item else {'GET'}
        if method not in allowed:
            raise APIError(405, 'method_not_allowed')
        if method == 'GET':
            if self.headers.get_all('Transfer-Encoding'):
                raise APIError(400, 'invalid_framing')
            if self.headers.get_all('Content-Length') and validation.content_length(self.headers) != 0:
                raise APIError(400, 'invalid_framing')
            if collection:
                rows = repository.list_tasks(self.server.db_path)
                self.send_json(200, {'tasks': [task_dto(row) for row in rows]})
            else:
                self.serve_static(path)
            return
        value = self.mutation_body()
        if collection:
            row = repository.create_task(self.server.db_path, value)
            self.send_json(201, {'task': task_dto(row)})
            return
        task_id = validation.parse_id(path[len('/api/tasks/'):])
        if task_id > 9223372036854775807:
            raise APIError(404, 'not_found')
        if method == 'PATCH':
            row = repository.set_completed(self.server.db_path, task_id, value)
            if row is None:
                raise APIError(404, 'not_found')
            self.send_json(200, {'task': task_dto(row)})
        else:
            deleted = repository.delete_task(self.server.db_path, task_id)
            if deleted is None:
                raise APIError(404, 'not_found')
            self.send_json(200, {'deleted': deleted})

    def serve_static(self, path):
        try:
            content = STATIC_FILES[path].read_bytes()
        except OSError:
            raise APIError(404, 'not_found') from None
        media = 'text/html' if path == '/' else 'text/javascript' if path == '/app.js' else 'text/css'
        self.send_bytes(200, content, media + '; charset=utf-8')


class BoundedHTTPServer(ThreadingHTTPServer):
    request_queue_size = 8
    daemon_threads = True

    def __init__(self, address, db_path):
        self.db_path = db_path
        self.slots = threading.BoundedSemaphore(8)
        super().__init__(address, TaskHandler)

    def process_request(self, request, client_address):
        if not self.slots.acquire(blocking=False):
            self.shutdown_request(request)
            return
        try:
            super().process_request(request, client_address)
        except BaseException:
            self.slots.release()
            raise

    def process_request_thread(self, request, client_address):
        try:
            super().process_request_thread(request, client_address)
        finally:
            self.slots.release()


def create_server(db_path, port):
    schema.initialize_database(db_path)
    return BoundedHTTPServer(('127.0.0.1', port), db_path)


def main(argv=None):
    parser = argparse.ArgumentParser(description='Local SQLite task board')
    parser.add_argument('--db', default='data/tasks.sqlite3')
    parser.add_argument('--port', type=int, default=8000)
    args = parser.parse_args(argv)
    if not 0 <= args.port <= 65535:
        parser.error('--port must be between 0 and 65535')
    try:
        server = create_server(args.db, args.port)
    except (schema.SchemaError, OSError) as error:
        print('Startup failed: ' + str(error), file=sys.stderr)
        return 1
    try:
        print(f'LISTENING http://127.0.0.1:{server.server_port}', flush=True)
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
