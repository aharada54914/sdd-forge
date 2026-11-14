"""Local task-board HTTP adapter. Runtime dependencies are all standard library."""
from __future__ import annotations

import argparse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import re
import sys
from urllib.parse import unquote, urlsplit

from store import StorageError, TaskNotFoundError, TaskStore, ValidationError


ROOT = Path(__file__).resolve().parent
BODY_LIMIT = 65536
ASSETS = {
    '/': ('web/index.html', 'text/html'),
    '/app.js': ('web/app.js', 'text/javascript'),
    '/styles.css': ('web/styles.css', 'text/css'),
    '/tokens.css': ('design-system/build/tokens.css', 'text/css'),
}


class RequestError(Exception):
    def __init__(self, status: int, message: str) -> None:
        self.status = status
        super().__init__(message)


def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
    result: dict[str, object] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate key')
        result[key] = value
    return result


def reject_constant(value: str) -> object:
    raise ValueError('non-JSON constant')


class TaskHTTPServer(ThreadingHTTPServer):
    def __init__(self, data_file: Path, port: int, static_root: Path) -> None:
        self.store = TaskStore(data_file)
        self.static_root = static_root.resolve()
        # No configurable bind address: even an alternate port stays local IPv4.
        super().__init__(('127.0.0.1', port), TaskHandler)


class TaskHandler(BaseHTTPRequestHandler):
    server: TaskHTTPServer
    timeout = 10

    def log_message(self, format: str, *args: object) -> None:
        # Base logging contains the request target. It can contain task text.
        # Status and storage failure class are logged explicitly instead.
        pass

    def send_error(self, code: int, message: str | None = None,
                   explain: str | None = None) -> None:
        if code == 501:
            # Base handler calls this for every unimplemented HTTP method.
            self.dispatch()
        else:
            self.reply_json(code, {'error': 'リクエストを処理できませんでした。'})

    def reply(self, status: int, content: bytes, mime: str) -> None:
        self.close_connection = True
        self.send_response(status)
        self.send_header('Content-Type', mime + '; charset=utf-8')
        self.send_header('Content-Length', str(len(content)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('Connection', 'close')
        self.end_headers()
        print(f'HTTP {status}', file=sys.stderr)
        if self.command != 'HEAD':
            self.wfile.write(content)

    def reply_json(self, status: int, document: object) -> None:
        self.reply(status, json.dumps(document, ensure_ascii=False).encode('utf-8'),
                   'application/json')

    def trust_checks(self) -> None:
        authorities = {f'localhost:{self.server.server_port}',
                       f'127.0.0.1:{self.server.server_port}'}
        hosts = self.headers.get_all('Host', [])
        if len(hosts) != 1 or hosts[0] not in authorities:
            raise RequestError(403, '接続先が許可されていません。')
        if self.command not in ('GET', 'HEAD'):
            origins = self.headers.get_all('Origin', [])
            if len(origins) > 1 or (origins and origins[0] not in {
                'http://' + authority for authority in authorities
            }):
                raise RequestError(403, '送信元が許可されていません。')

    def body_length(self) -> int:
        if self.headers.get_all('Transfer-Encoding') is not None:
            raise RequestError(400, '転送形式が無効です。')
        lengths = self.headers.get_all('Content-Length', [])
        if not lengths and self.command in ('POST', 'PATCH'):
            raise RequestError(400, '本文の長さを指定してください。')
        if not lengths:
            return 0
        if len(lengths) != 1 or not re.fullmatch(r'[0-9]+', lengths[0]):
            raise RequestError(400, '本文の長さが無効です。')
        digits = lengths[0].lstrip('0') or '0'
        # Compare before int conversion so enormous decimal headers stay bounded.
        if len(digits) > 5 or (len(digits) == 5 and digits > str(BODY_LIMIT)):
            raise RequestError(413, 'リクエストが大きすぎます。')
        return int(digits)

    def json_body(self, length: int, field: str) -> object:
        types = self.headers.get_all('Content-Type', [])
        if len(types) != 1 or not re.fullmatch(
            r'application/json(?:\s*;\s*charset=(?:utf-8|"utf-8"))?',
            types[0].strip(), flags=re.IGNORECASE,
        ):
            raise RequestError(415, 'JSON形式で送信してください。')
        try:
            raw = self.rfile.read(length)
        except (TimeoutError, OSError) as exc:
            raise RequestError(400, '本文を読み取れませんでした。') from exc
        if len(raw) != length:
            raise RequestError(400, '本文の長さが一致しません。')
        try:
            document = json.loads(raw.decode('utf-8'), object_pairs_hook=unique_object,
                                  parse_constant=reject_constant)
        except (ValueError, UnicodeError, RecursionError) as exc:
            raise RequestError(400, 'JSON形式が無効です。') from exc
        if not isinstance(document, dict) or set(document) != {field}:
            raise RequestError(400, '入力項目が無効です。')
        return document[field]

    def route(self) -> str:
        try:
            if not self.path.startswith('/') or self.path.startswith('//'):
                raise ValueError('not an origin-form target')
            return unquote(urlsplit(self.path).path, encoding='utf-8', errors='strict')
        except (ValueError, UnicodeError) as exc:
            raise RequestError(404, 'ページが見つかりません。') from exc

    def static(self, route: str) -> None:
        relative, mime = ASSETS[route]
        candidate = self.server.static_root
        # Fixed asset names only; symlink substitution must not expose store JSON.
        for component in Path(relative).parts:
            candidate = candidate / component
            if candidate.is_symlink():
                raise RequestError(404, 'ファイルが見つかりません。')
        try:
            content = candidate.read_bytes()
        except OSError as exc:
            raise RequestError(404, 'ファイルが見つかりません。') from exc
        self.reply(200, content, mime)

    def dispatch(self) -> None:
        try:
            self.trust_checks()
            if self.command not in ('GET', 'POST', 'PATCH', 'DELETE'):
                raise RequestError(405, 'この操作は利用できません。')
            length = self.body_length()
            if self.command in ('GET', 'DELETE') and length:
                raise RequestError(400, 'この操作に本文は指定できません。')
            route = self.route()
            if route in ASSETS:
                if self.command != 'GET':
                    raise RequestError(405, 'この操作は利用できません。')
                self.static(route)
                return
            if route == '/api/tasks':
                if self.command == 'GET':
                    tasks = self.server.store.snapshot()
                elif self.command == 'POST':
                    tasks = self.server.store.add(self.json_body(length, 'title'))
                else:
                    raise RequestError(405, 'この操作は利用できません。')
            elif re.fullmatch(r'/api/tasks/[^/]+', route):
                identity = route.removeprefix('/api/tasks/')
                if self.command == 'PATCH':
                    tasks = self.server.store.set_completed(
                        identity, self.json_body(length, 'completed'))
                elif self.command == 'DELETE':
                    tasks = self.server.store.delete(identity)
                else:
                    raise RequestError(405, 'この操作は利用できません。')
            else:
                raise RequestError(404, 'ページが見つかりません。')
            self.reply_json(201 if self.command == 'POST' else 200, {'tasks': tasks})
        except RequestError as exc:
            self.reply_json(exc.status, {'error': str(exc)})
        except ValidationError as exc:
            self.reply_json(400, {'error': str(exc)})
        except TaskNotFoundError as exc:
            self.reply_json(404, {'error': str(exc)})
        except StorageError:
            print('StorageError', file=sys.stderr)
            self.reply_json(500, {'error': '保存データを読み書きできませんでした。'})

    do_GET = dispatch
    do_POST = dispatch
    do_PATCH = dispatch
    do_DELETE = dispatch


def create_server(data_file: Path, *, port: int = 8000,
                  static_root: Path = ROOT) -> TaskHTTPServer:
    """Create a loopback server; static_root permits isolated synthetic asset tests."""
    return TaskHTTPServer(data_file, port, static_root)


def main() -> int:
    parser = argparse.ArgumentParser(description='ローカルのタスクボード')
    parser.add_argument('--port', type=int, default=8000)
    parser.add_argument('--data-file', type=Path, default=ROOT / 'data' / 'tasks.json')
    args = parser.parse_args()
    if not 0 <= args.port <= 65535:
        parser.error('port must be between 0 and 65535')
    try:
        httpd = create_server(args.data_file, port=args.port)
    except OSError:
        print('サーバーを起動できませんでした。ポートを確認してください。', file=sys.stderr)
        return 1
    with httpd:
        print(f'http://127.0.0.1:{httpd.server_port}', flush=True)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
