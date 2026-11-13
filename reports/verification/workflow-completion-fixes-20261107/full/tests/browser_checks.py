"""Real Chromium acceptance checks; each run owns a new evidence directory.

Run: python3 tests/browser_checks.py --output-dir <new-directory>
Use --full to include the admitted store/HTTP/token regression suites.
No application or test fixture is copied; all task data is created through HTTP.
"""
from __future__ import annotations

import argparse
import asyncio
from contextlib import contextmanager
import hashlib
from http.client import HTTPConnection
import importlib.metadata
import json
import os
from pathlib import Path
import platform
import socket
import subprocess
import sys
import tempfile
import time
import traceback
from typing import Any, Iterator
from urllib.parse import urlsplit

from playwright.async_api import Browser, Page, Route, async_playwright, expect


ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / 'specs/task-board/mockups/imagegen-reference.png'
REFERENCE_HASH = '60049c2b9d49f059afbe50ec43cc0d0802bae75b15b5dde090c4acdaf00127d8'


class Server:
    """A real child server, restarted against the same owned temporary JSON."""

    def __init__(self, data: Path, log: Path) -> None:
        self.data = data
        self.log = log
        self.process: subprocess.Popen[str] | None = None
        self.url = ''

    def start(self) -> None:
        with self.log.open('a') as errors:
            self.process = subprocess.Popen(
                [sys.executable, '-B', str(ROOT / 'server.py'), '--port', '0',
                 '--data-file', str(self.data)], cwd=ROOT,
                stdout=subprocess.PIPE, stderr=errors, text=True,
            )
        assert self.process.stdout is not None
        self.url = self.process.stdout.readline().strip()
        assert self.url.startswith('http://127.0.0.1:'), self.url

    def stop(self) -> None:
        if self.process is not None:
            self.process.terminate()
            self.process.wait(timeout=5)
            if self.process.stdout is not None:
                self.process.stdout.close()


@contextmanager
def running_server(output: Path, name: str) -> Iterator[Server]:
    with tempfile.TemporaryDirectory(prefix=name + '-', dir=output) as temp:
        server = Server(Path(temp) / 'tasks.json', output / (name + '-server.log'))
        server.start()
        try:
            yield server
        finally:
            server.stop()


def api(server: Server, method: str = 'GET', path: str = '/api/tasks',
        body: object = None) -> tuple[int, Any]:
    parsed = urlsplit(server.url)
    conn = HTTPConnection('127.0.0.1', parsed.port, timeout=5)
    try:
        data = None if body is None else json.dumps(body, ensure_ascii=False).encode()
        conn.request(method, path, data, {'Content-Type': 'application/json'})
        response = conn.getresponse()
        raw = response.read()
        return response.status, json.loads(raw)
    finally:
        conn.close()


async def open_board(page: Page, server: Server) -> None:
    response = await page.goto(server.url)
    assert response is not None and response.status == 200
    await expect(page.get_by_role('heading', name='今日のタスク', exact=True)).to_be_visible()
    await expect(page.get_by_role('button', name='追加', exact=True)).to_be_enabled()


async def add(page: Page, title: str) -> None:
    await page.get_by_label('新しいタスク', exact=True).fill(title)
    await page.get_by_role('button', name='追加', exact=True).click()
    await expect(page.get_by_label('新しいタスク', exact=True)).to_have_value('')


async def crud(page: Page, server: Server, output: Path) -> dict[str, Any]:
    await open_board(page, server)
    await expect(page.get_by_text('タスクはまだありません', exact=True)).to_be_visible()
    assert await page.locator('html').get_attribute('lang') == 'ja'
    field = page.get_by_label('新しいタスク', exact=True)
    await field.focus()
    await page.keyboard.insert_text('  買い物  ')
    await page.keyboard.press('Enter')
    await expect(page.get_by_role('checkbox', name='買い物', exact=True)).to_be_visible()
    await expect(field).to_have_value('')
    await expect(field).to_be_focused()
    status, snapshot = api(server)
    assert status == 200 and len(snapshot['tasks']) == 1
    assert snapshot['tasks'][0]['title'] == '買い物'
    checkbox = page.get_by_role('checkbox', name='買い物', exact=True)
    await page.keyboard.press('Tab')
    await expect(page.get_by_role('button', name='追加', exact=True)).to_be_focused()
    await page.keyboard.press('Tab')
    await expect(checkbox).to_be_focused()
    await page.keyboard.press('Space')
    await expect(checkbox).to_be_checked()
    await expect(checkbox).to_be_enabled()
    await page.reload()
    await expect(checkbox).to_be_checked()
    await checkbox.click()
    await expect(checkbox).to_be_enabled()
    await expect(checkbox).not_to_be_checked()
    await page.reload()
    await expect(checkbox).not_to_be_checked()
    await add(page, '連絡する')
    row = page.get_by_role('listitem').filter(has=checkbox)
    delete = row.get_by_role('button', name='削除', exact=True)
    await delete.focus()
    await page.keyboard.press('Enter')
    dialog = page.get_by_role('dialog', name='タスクを削除しますか？')
    await expect(dialog).to_be_visible()
    await expect(dialog.get_by_role('button', name='キャンセル')).to_be_focused()
    before = server.data.read_bytes()
    await page.keyboard.press('Enter')
    await expect(dialog).not_to_be_visible()
    await expect(delete).to_be_focused()
    assert server.data.read_bytes() == before
    await delete.click()
    await page.keyboard.press('Escape')
    await expect(delete).to_be_focused()
    await delete.click()
    await dialog.get_by_role('button', name='削除', exact=True).click()
    await expect(checkbox).to_have_count(0)
    await expect(page.get_by_role('checkbox', name='連絡する', exact=True)).to_be_focused()
    await page.reload()
    await expect(checkbox).to_have_count(0)
    await add(page, '最後のタスク')
    last_row = page.get_by_role('listitem').filter(
        has=page.get_by_role('checkbox', name='最後のタスク', exact=True))
    await last_row.get_by_role('button', name='削除', exact=True).click()
    await dialog.get_by_role('button', name='削除', exact=True).click()
    await expect(page.get_by_role('checkbox', name='最後のタスク', exact=True)).to_have_count(0)
    await expect(page.get_by_role('checkbox', name='連絡する', exact=True)).to_be_focused()
    await page.get_by_role('button', name='削除', exact=True).click()
    await page.screenshot(path=str(output / 'delete-dialog.png'), full_page=True)
    await dialog.get_by_role('button', name='削除', exact=True).click()
    await expect(field).to_be_focused()
    await expect(page.get_by_text('タスクはまだありません', exact=True)).to_be_visible()
    return {'tests': ['TEST-001', 'TEST-003', 'TEST-004', 'TEST-010'],
            'add_check_uncheck_reload_delete_cancel_keyboard_focus': 'PASS'}


async def validation(page: Page, server: Server, output: Path) -> dict[str, Any]:
    await open_board(page, server)
    field = page.get_by_label('新しいタスク', exact=True)
    writes: list[str] = []
    page.on('request', lambda req: writes.append(req.method)
            if req.method in ('POST', 'PATCH', 'DELETE') else None)
    for blank in ('', ' ', '\u3000', '\n'):
        await field.fill(blank)
        await page.get_by_role('button', name='追加', exact=True).click()
        await expect(page.get_by_role('alert')).to_contain_text('入力')
        assert api(server)[1]['tasks'] == []
    assert writes == []
    astral = '🌱' * 500
    await field.fill('')
    await field.focus()
    await page.keyboard.insert_text(astral)
    await expect(field).to_have_value(astral)
    await page.keyboard.press('Enter')
    await expect(field).to_have_value('')
    assert api(server)[1]['tasks'][0]['title'] == astral
    assert len(writes) == 1
    before = server.data.read_bytes()
    await page.keyboard.insert_text(astral + '🌱')
    await expect(field).to_have_value(astral + '🌱')
    await page.keyboard.press('Enter')
    await expect(page.get_by_role('alert')).to_contain_text('500')
    assert server.data.read_bytes() == before and len(writes) == 1
    # Python str.strip includes these control whitespace characters; JS trim doesn't.
    await add(page, '\u001c\u0085正常\u0085\u001f')
    assert api(server)[1]['tasks'][-1]['title'] == '正常'
    literal = '<img src=x onerror="window.__xss=true"> & <script>alert(1)</script>'
    await add(page, literal)
    await expect(page.get_by_role('checkbox', name=literal, exact=True)).to_be_visible()
    assert await page.locator('main img, main script').count() == 0
    assert await page.evaluate('window.__xss === undefined')
    return {'tests': ['TEST-002', 'TEST-009'], 'blank_variants': 4,
            'inserted_astral_codepoints': 500, 'rejected_astral_codepoints': 501,
            'literal_html': 'PASS'}


async def pending(page: Page, server: Server, output: Path) -> dict[str, Any]:
    await open_board(page, server)
    await add(page, '既存タスク')
    release = asyncio.Event()
    received = asyncio.Event()
    writes: list[str] = []

    async def delay(route: Route) -> None:
        if route.request.method == 'GET':
            await route.continue_()
            return
        writes.append(route.request.method)
        response = await route.fetch()
        received.set()
        await release.wait()
        await route.fulfill(response=response)

    await page.route('**/api/tasks**', delay)
    field = page.get_by_label('新しいタスク', exact=True)
    await field.fill('一度だけ')
    await field.press('Enter')
    await asyncio.wait_for(received.wait(), timeout=5)
    for control in ('input', 'main button'):
        for element in await page.locator(control).all():
            await expect(element).to_be_disabled()
    await expect(page.get_by_role('status')).to_contain_text('保存中')
    await page.screenshot(path=str(output / 'saving.png'), full_page=True)
    await page.keyboard.press('Enter')
    await page.keyboard.press('Space')
    # DOM-dispatched events challenge the synchronous guard in addition to disabled UI.
    await page.evaluate('''() => {
      for (let i = 0; i < 8; i++) {
        document.querySelector('form').dispatchEvent(new Event('submit', {cancelable: true}));
        document.querySelector('input[type=checkbox]').dispatchEvent(new Event('change'));
        document.querySelector('li button').dispatchEvent(new MouseEvent('click'));
      }
    }''')
    await page.wait_for_timeout(150)
    assert writes == ['POST'], writes
    assert await page.get_by_role('dialog').count() == 0
    release.set()
    await expect(field).to_have_value('')
    await expect(field).to_be_enabled()
    await page.unroute('**/api/tasks**', delay)
    await page.get_by_role('checkbox', name='既存タスク', exact=True).click()
    await expect(page.get_by_role('checkbox', name='既存タスク', exact=True)).to_be_enabled()
    await expect(page.get_by_role('checkbox', name='既存タスク', exact=True)).to_be_checked()
    assert api(server)[1]['tasks'][0]['completed'] is True
    return {'tests': ['TEST-006'], 'delayed_mutations': writes,
            'server_saved_titles': [t['title'] for t in api(server)[1]['tasks']]}


async def failures(page: Page, server: Server, output: Path) -> dict[str, Any]:
    await open_board(page, server)
    await add(page, '元のタスク')
    field = page.get_by_label('新しいタスク', exact=True)
    await field.fill('保持する入力')
    attempts: list[str] = []

    async def fail(route: Route) -> None:
        if route.request.method == 'GET':
            await route.continue_()
        else:
            attempts.append(route.request.method)
            await route.fulfill(status=500, content_type='application/json',
                                body=json.dumps({'error': '保存できませんでした。'}))

    await page.route('**/api/tasks**', fail)
    before = server.data.read_bytes()
    await page.get_by_role('button', name='追加', exact=True).click()
    await expect(page.get_by_role('alert')).to_contain_text('再読み込み')
    await expect(field).to_have_value('保持する入力')
    await expect(field).to_be_enabled()
    await page.screenshot(path=str(output / 'save-error.png'), full_page=True)
    await page.wait_for_timeout(300)
    assert attempts == ['POST'] and server.data.read_bytes() == before
    checkbox = page.get_by_role('checkbox', name='元のタスク', exact=True)
    await checkbox.click()
    await expect(checkbox).to_be_enabled()
    await expect(checkbox).not_to_be_checked()
    await page.get_by_role('button', name='削除', exact=True).click()
    await page.get_by_role('dialog').get_by_role('button', name='削除', exact=True).click()
    await expect(checkbox).to_be_enabled()
    await expect(checkbox).to_be_visible()
    assert server.data.read_bytes() == before
    assert attempts == ['POST', 'PATCH', 'DELETE']
    await page.unroute('**/api/tasks**', fail)
    lost: list[str] = []

    async def lose_response(route: Route) -> None:
        if route.request.method == 'POST':
            lost.append(route.request.method)
            await route.fetch()  # The write commits; only its response is lost.
            await route.abort('failed')
        else:
            await route.continue_()

    await page.route('**/api/tasks**', lose_response)
    await page.get_by_role('button', name='追加', exact=True).click()
    await expect(page.get_by_role('alert')).to_contain_text('再読み込み')
    await expect(field).to_be_enabled()
    await expect(field).to_have_value('保持する入力')
    await page.wait_for_timeout(300)
    assert lost == ['POST']
    assert len(api(server)[1]['tasks']) == 2
    await expect(page.get_by_role('checkbox')).to_have_count(1)
    await page.unroute('**/api/tasks**', lose_response)
    await page.reload()
    await expect(page.get_by_role('checkbox', name='保持する入力', exact=True)).to_be_visible()

    async def malformed(route: Route) -> None:
        await route.fulfill(status=201, content_type='application/json',
                            body='{"tasks":[{"id":"bad","title":1,"completed":"yes"}]}')

    await page.route('**/api/tasks', malformed)
    await field.fill('不正応答でも保持')
    await page.get_by_role('button', name='追加', exact=True).click()
    await expect(page.get_by_role('alert')).to_contain_text('再読み込み')
    await expect(field).to_have_value('不正応答でも保持')
    await expect(page.get_by_role('checkbox')).to_have_count(2)
    await page.unroute('**/api/tasks', malformed)
    return {'tests': ['TEST-007'], 'failed_write_attempts': attempts,
            'lost_response_attempts': lost, 'auto_retry': False,
            'malformed_response_preserves_snapshot': True}


async def loading(page: Page, server: Server, output: Path) -> dict[str, Any]:
    release = asyncio.Event()
    received = asyncio.Event()
    requests: list[str] = []

    async def delay_get(route: Route) -> None:
        requests.append(route.request.method)
        received.set()
        await release.wait()
        await route.continue_()

    await page.route('**/api/tasks', delay_get)
    await page.goto(server.url, wait_until='domcontentloaded')
    await asyncio.wait_for(received.wait(), timeout=5)
    await expect(page.get_by_role('status')).to_contain_text('読み込み中')
    await expect(page.get_by_role('button', name='追加', exact=True)).to_be_disabled()
    await expect(page.get_by_label('新しいタスク', exact=True)).to_be_disabled()
    await expect(page.get_by_text('タスクはまだありません', exact=True)).not_to_be_visible()
    await page.screenshot(path=str(output / 'loading.png'), full_page=True)
    release.set()
    await expect(page.get_by_role('button', name='追加', exact=True)).to_be_enabled()
    await expect(page.get_by_text('タスクはまだありません', exact=True)).to_be_visible()
    await page.screenshot(path=str(output / 'empty.png'), full_page=True)
    await page.unroute('**/api/tasks', delay_get)

    async def fail_get(route: Route) -> None:
        requests.append(route.request.method)
        await route.fulfill(status=500, content_type='application/json',
                            body=json.dumps({'error': '読み込みできませんでした。'}))

    await page.route('**/api/tasks', fail_get)
    await page.reload()
    await expect(page.get_by_role('alert')).to_contain_text('再読み込み')
    await expect(page.get_by_text('タスクはまだありません', exact=True)).not_to_be_visible()
    await page.screenshot(path=str(output / 'get-error.png'), full_page=True)
    await page.wait_for_timeout(300)
    assert requests == ['GET', 'GET']
    await page.unroute('**/api/tasks', fail_get)
    await page.reload()
    await expect(page.get_by_text('タスクはまだありません', exact=True)).to_be_visible()
    return {'tests': ['TEST-010'], 'loading_error_recovery': 'PASS', 'GET_count': 2}


async def timeout(page: Page, server: Server, output: Path) -> dict[str, Any]:
    await open_board(page, server)
    writes: list[str] = []
    release = asyncio.Event()

    async def stall(route: Route) -> None:
        writes.append(route.request.method)
        await release.wait()
        await route.abort('timedout')

    await page.route('**/api/tasks', stall)
    field = page.get_by_label('新しいタスク', exact=True)
    await field.fill('タイムアウトでも保持')
    started = time.monotonic()
    await page.get_by_role('button', name='追加', exact=True).click()
    await expect(page.get_by_role('alert')).to_contain_text('再読み込み', timeout=12000)
    elapsed = time.monotonic() - started
    await expect(field).to_have_value('タイムアウトでも保持')
    await expect(field).to_be_enabled()
    assert 9.5 <= elapsed < 12 and writes == ['POST']
    release.set()
    await page.unroute_all(behavior='wait')
    return {'tests': ['TEST-007'], 'timeout_seconds': elapsed, 'requests': writes}


async def visual(page: Page, server: Server, output: Path) -> dict[str, Any]:
    reference_hash = hashlib.sha256(REFERENCE.read_bytes()).hexdigest()
    assert reference_hash == REFERENCE_HASH
    for title in ('買い物に行く', '週末の予定を整理する', '読みかけの本を読む',
                  '来週の準備を進めるために必要なものを確認して、余裕をもって一日を過ごす。' * 4):
        assert api(server, 'POST', body={'title': title})[0] == 201
    first = api(server)[1]['tasks'][0]
    assert api(server, 'PATCH', '/api/tasks/' + first['id'], {'completed': True})[0] == 200
    await open_board(page, server)
    observed: list[dict[str, Any]] = []
    for width in (1440, 390, 320):
        await page.set_viewport_size({'width': width, 'height': 1000 if width == 1440 else 844})
        await page.screenshot(path=str(output / f'board-{width}.png'), full_page=True)
        metrics = await page.evaluate('''() => {
          const main = document.querySelector('main');
          const button = document.querySelector('button[type=submit]');
          const field = document.querySelector('input[type=text]');
          const row = document.querySelector('li');
          const style = getComputedStyle(main);
          return {viewport: innerWidth, scroll: document.documentElement.scrollWidth,
            mainWidth: main.getBoundingClientRect().width,
            font: style.fontFamily, text: style.color, background: getComputedStyle(document.body).backgroundColor,
            primary: getComputedStyle(button).backgroundColor,
            radius: getComputedStyle(row).borderRadius,
            inputY: field.getBoundingClientRect().y, buttonY: button.getBoundingClientRect().y,
            minTarget: Math.min(...[...document.querySelectorAll('main button, main input')]
              .filter(x => x.getBoundingClientRect().width > 0)
              .map(x => x.getBoundingClientRect().height))};
        }''')
        assert metrics['scroll'] <= width and metrics['mainWidth'] <= 880
        assert metrics['minTarget'] >= 44
        assert metrics['text'] == 'rgb(16, 32, 56)'
        assert metrics['background'] == 'rgb(255, 255, 255)'
        assert metrics['primary'] == 'rgb(0, 127, 120)' and metrics['radius'] == '8px'
        if width < 640:
            assert metrics['buttonY'] > metrics['inputY']
        else:
            assert metrics['buttonY'] == metrics['inputY']
        observed.append(metrics)
    # CSS zoom doubles actual content/control size; viewport remains 640 CSS pixels.
    await page.set_viewport_size({'width': 640, 'height': 1000})
    await page.evaluate("document.documentElement.style.zoom = '2'")
    await page.screenshot(path=str(output / 'board-200pct.png'), full_page=True)
    assert await page.evaluate('document.documentElement.scrollWidth <= innerWidth')
    await page.evaluate("document.documentElement.style.zoom = ''")
    assert await page.locator('nav, aside, img').count() == 0
    (output / 'accessibility.yml').write_text(await page.locator('body').aria_snapshot())
    (output / 'computed-styles.json').write_text(json.dumps(observed, ensure_ascii=False, indent=2))
    return {'tests': ['TEST-008'], 'reference_sha256': reference_hash,
            'viewports': observed, 'zoom_200_percent': 'PASS',
            'zoom_method': 'CSS zoom 2; actual doubled content/control geometry'}


async def performance(page: Page, server: Server, output: Path) -> dict[str, Any]:
    for number in range(100):
        assert api(server, 'POST', body={'title': f'確認する項目 {number + 1}'})[0] == 201
    await open_board(page, server)
    await expect(page.get_by_role('checkbox')).to_have_count(100)
    # Browser clock brackets an input event and a successful checkbox re-render.
    measurements = await page.evaluate('''async () => {
      const field = document.querySelector('input[type=text]');
      const started = performance.now();
      field.value = '応答確認'; field.dispatchEvent(new Event('input', {bubbles: true}));
      await new Promise(requestAnimationFrame);
      const inputMs = performance.now() - started;
      const checkbox = document.querySelector('input[type=checkbox]');
      const toggleStart = performance.now(); checkbox.click();
      await new Promise((resolve, reject) => {
        const deadline = setTimeout(() => reject(new Error('toggle timeout')), 5000);
        const check = () => {
          const current = document.querySelector('input[type=checkbox]');
          if (current.checked && !current.disabled) { clearTimeout(deadline); resolve(); }
          else requestAnimationFrame(check);
        }; requestAnimationFrame(check);
      });
      return {input_ms: inputMs, checkbox_ms: performance.now() - toggleStart};
    }''')
    assert measurements['input_ms'] < 200 and measurements['checkbox_ms'] < 200
    size = sum((ROOT / path).stat().st_size for path in
               ('web/index.html', 'web/styles.css', 'web/app.js', 'design-system/build/tokens.css'))
    assert size < 100 * 1024
    return {'tests': ['TEST-008'], 'tasks': 100, 'browser_timing': measurements,
            'initial_assets_bytes': size}


async def restart(page: Page, server: Server, output: Path) -> dict[str, Any]:
    await open_board(page, server)
    await add(page, '再起動後も残す')
    box = page.get_by_role('checkbox', name='再起動後も残す', exact=True)
    await box.click()
    await expect(box).to_be_enabled()
    await expect(box).to_be_checked()
    before = api(server)[1]
    disk = server.data.read_bytes()
    server.stop()
    server.start()
    assert api(server)[1] == before and server.data.read_bytes() == disk
    await open_board(page, server)
    await expect(box).to_be_checked()
    return {'tests': ['TEST-005'], 'restart_snapshot': before, 'disk_preserved': True}


async def sockets(page: Page, server: Server, output: Path) -> dict[str, Any]:
    await open_board(page, server)
    assert server.process is not None
    port = urlsplit(server.url).port
    assert port is not None
    pid = server.process.pid
    # /proc is OS socket evidence, tied to the actual child PID's open descriptors.
    inodes = set()
    for fd in Path(f'/proc/{pid}/fd').iterdir():
        try:
            target = os.readlink(fd)
        except FileNotFoundError:
            continue
        if target.startswith('socket:['):
            inodes.add(target[8:-1])
    listeners = []
    raw_tables: dict[str, str] = {}
    for family in ('tcp', 'tcp6'):
        raw = Path(f'/proc/net/{family}').read_text()
        raw_tables[family] = raw
        for line in raw.splitlines()[1:]:
            columns = line.split()
            if columns[3] == '0A' and int(columns[1].split(':')[1], 16) == port:
                listeners.append({'family': family, 'address_hex': columns[1].split(':')[0],
                                  'inode': columns[9], 'owned_by_pid': columns[9] in inodes})
    assert len(listeners) == 1
    assert listeners[0]['family'] == 'tcp' and listeners[0]['address_hex'] == '0100007F'
    assert listeners[0]['owned_by_pid']
    addresses = sorted({str(entry[4][0]) for entry in socket.getaddrinfo(socket.gethostname(),
                        None, socket.AF_INET) if not str(entry[4][0]).startswith('127.')})
    assert addresses, 'AC-013 UNVERIFIED: no real nonloopback IPv4 interface'
    probes = []
    for address in addresses:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as client:
            client.settimeout(2)
            result = client.connect_ex((address, port))
        assert result != 0, (address, port)
        probes.append({'address': address, 'port': port, 'connect_ex': result})
    evidence = {'tests': ['TEST-012'], 'pid': pid, 'port': port, 'listeners': listeners,
                'loopback_GET': 200, 'nonloopback_probes': probes, 'proc_tables': raw_tables}
    (output / 'socket-evidence.json').write_text(json.dumps(evidence, indent=2))
    return evidence


CASES = {'crud': crud, 'mobile-crud': crud, 'validation': validation, 'pending': pending, 'failures': failures,
         'loading': loading, 'timeout': timeout, 'visual': visual,
         'performance': performance, 'restart': restart, 'sockets': sockets}


async def run(args: argparse.Namespace, output: Path) -> int:
    results: dict[str, Any] = {'command': sys.argv, 'python': platform.python_version(),
                               'playwright': importlib.metadata.version('playwright'),
                               'browser_executable': args.chromium, 'cases': {}}
    failed = False
    async with async_playwright() as playwright:
        browser: Browser = await playwright.chromium.launch(
            executable_path=args.chromium, headless=True, args=['--no-sandbox'])
        results['browser'] = browser.version
        try:
            for name in args.case or CASES:
                case_output = output / name
                case_output.mkdir()
                context = await browser.new_context(viewport={'width': 390 if name == 'mobile-crud' else 1440,
                                                             'height': 1000},
                                                    locale='ja-JP')
                page = await context.new_page()
                page.set_default_timeout(5000)
                page_errors: list[str] = []
                console_errors: list[str] = []
                page.on('pageerror', lambda error: page_errors.append(str(error)))
                page.on('console', lambda message: console_errors.append(message.text)
                        if message.type == 'error' else None)
                started = time.monotonic()
                try:
                    with running_server(case_output, name) as server:
                        evidence = await CASES[name](page, server, case_output)
                    assert not page_errors, page_errors
                    # Fault tests deliberately cause browser network errors; all are retained.
                    unexpected = [error for error in console_errors if not (
                        error.startswith('Failed to load resource:') and
                        name in ('failures', 'loading', 'timeout'))]
                    assert not unexpected, unexpected
                    results['cases'][name] = {'status': 'PASS', 'evidence': evidence}
                    print(f'PASS {name}', flush=True)
                except Exception:
                    failed = True
                    failure = traceback.format_exc()
                    results['cases'][name] = {'status': 'FAIL', 'traceback': failure}
                    print(f'FAIL {name}\n{failure}', flush=True)
                    await page.screenshot(path=str(case_output / 'failure.png'), full_page=True)
                finally:
                    results['cases'][name].update(seconds=time.monotonic() - started,
                                                  page_errors=page_errors,
                                                  console_errors=console_errors)
                    await context.close()
        finally:
            await browser.close()
    if args.full:
        command = [sys.executable, '-B', '-m', 'unittest', 'discover', '-s', 'tests', '-v']
        check = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=False)
        (output / 'unit-regressions.log').write_text(check.stdout + check.stderr)
        results['regression'] = {'command': command, 'exit_code': check.returncode}
        failed = failed or check.returncode != 0
    results['exit_code'] = int(failed)
    (output / 'results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2))
    return int(failed)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--case', action='append', choices=list(CASES))
    parser.add_argument('--chromium', default='/usr/bin/chromium')
    parser.add_argument('--full', action='store_true')
    args = parser.parse_args()
    output = args.output_dir or ROOT / 'reports/visual-evidence/task-board/T-004' / (
        time.strftime('run-%Y%m%dT%H%M%S') + '-' + str(os.getpid()))
    # Frozen evidence is never overwritten, including by later T-005 invocations.
    output.mkdir(parents=True, exist_ok=False)
    print('Evidence:', output, flush=True)
    return asyncio.run(run(args, output))


if __name__ == '__main__':
    raise SystemExit(main())
