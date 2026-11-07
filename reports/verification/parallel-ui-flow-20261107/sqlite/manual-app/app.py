import json
import os
import sqlite3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).parent
DB = os.environ.get('TASK_DB', str(ROOT / 'tasks.sqlite3'))

def connect():
    db = sqlite3.connect(DB, timeout=10)
    db.row_factory = sqlite3.Row
    db.execute('CREATE TABLE IF NOT EXISTS tasks(id INTEGER PRIMARY KEY, title TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0)')
    db.commit()
    return db

class Handler(BaseHTTPRequestHandler):
    def reply(self, status, body):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == '/':
            data = (ROOT / 'index.html').read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
        elif self.path == '/api/tasks':
            with connect() as db:
                rows = [dict(row) for row in db.execute('SELECT * FROM tasks ORDER BY id DESC')]
            self.reply(200, rows)
        else:
            self.reply(404, {'error': 'Not found'})

    def do_POST(self):
        if self.path != '/api/tasks':
            return self.reply(404, {'error': 'Not found'})
        try:
            length = int(self.headers.get('Content-Length', '0'))
            if not 0 < length <= 4096:
                raise ValueError('Invalid request size')
            payload = json.loads(self.rfile.read(length))
            title = payload.get('title') if isinstance(payload, dict) else None
            if not isinstance(title, str) or not 1 <= len(title.strip()) <= 200:
                raise ValueError('Title must contain 1–200 characters')
        except (ValueError, UnicodeDecodeError) as error:
            return self.reply(400, {'error': str(error)})
        with connect() as db:
            cursor = db.execute('INSERT INTO tasks(title) VALUES (?)', (title.strip(),))
            task_id = cursor.lastrowid
        self.reply(201, {'id': task_id})

    def mutate(self, sql):
        if not self.path.startswith('/api/tasks/') or not self.path[11:].isdigit():
            return self.reply(404, {'error': 'Not found'})
        with connect() as db:
            changed = db.execute(sql, (int(self.path[11:]),)).rowcount
        self.reply(200 if changed else 404, {'ok': bool(changed)})

    def do_PATCH(self):
        self.mutate('UPDATE tasks SET done = 1 - done WHERE id = ?')

    def do_DELETE(self):
        self.mutate('DELETE FROM tasks WHERE id = ?')

if __name__ == '__main__':
    connect().close()
    ThreadingHTTPServer(('127.0.0.1', int(os.environ.get('PORT', '8133'))), Handler).serve_forever()
