"""Local diagnostic app; not a completed SDD full run."""
import json
import os
from pathlib import Path
from http.server import BaseHTTPRequestHandler, HTTPServer
from uuid import uuid4

ROOT = Path(__file__).resolve().parent
DATA = ROOT / 'tasks.json'

class Handler(BaseHTTPRequestHandler):
    def reply(self, status, value):
        raw = json.dumps(value).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        if self.path == '/api/tasks':
            return self.reply(200, json.loads(DATA.read_text()) if DATA.exists() else [])
        if self.path != '/':
            return self.reply(404, {'error': 'Not found'})
        raw = (ROOT / 'index.html').read_bytes()
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(raw)

    def do_POST(self):
        if self.headers.get('Origin') not in (None, 'http://127.0.0.1:8766'):
            return self.reply(403, {'error': 'Origin rejected'})
        try:
            length = int(self.headers.get('Content-Length', 0))
            if not 0 < length <= 4096:
                return self.reply(400, {'error': 'Invalid body size'})
            body = json.loads(self.rfile.read(length))
            tasks = json.loads(DATA.read_text()) if DATA.exists() else []
            if self.path == '/api/tasks':
                title = body.get('title', '')
                if not isinstance(title, str) or not title.strip() or len(title) > 200:
                    return self.reply(400, {'error': 'Title must contain 1–200 characters'})
                tasks.append({'id': str(uuid4()), 'title': title.strip(), 'done': False})
            elif self.path in ('/api/toggle', '/api/delete'):
                found = next((task for task in tasks if task['id'] == body.get('id')), None)
                if found is None:
                    return self.reply(404, {'error': 'Task not found'})
                if self.path == '/api/toggle':
                    found['done'] = not found['done']
                else:
                    tasks.remove(found)
            else:
                return self.reply(404, {'error': 'Not found'})
            temp = DATA.with_suffix('.tmp')
            temp.write_text(json.dumps(tasks))
            os.replace(temp, DATA)
            self.reply(200, tasks)
        except (ValueError, TypeError, AttributeError):
            self.reply(400, {'error': 'Invalid JSON'})

if __name__ == '__main__':
    HTTPServer(('127.0.0.1', 8766), Handler).serve_forever()
