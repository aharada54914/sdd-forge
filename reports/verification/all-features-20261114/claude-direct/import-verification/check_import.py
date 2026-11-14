import json
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
from urllib.request import urlopen
from playwright.sync_api import sync_playwright, expect

base = Path('/workspace/.tools/sdd-forge-dev/verification-workspace')
out = Path(__file__).resolve().parent
results = []
with sync_playwright() as p:
    browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True, args=['--no-sandbox'])
    for flavor in ('full', 'sqlite'):
        for variant in ('fixed', 'claude-ui'):
            root = base / f'{flavor}-task-board-{variant}'
            with tempfile.TemporaryDirectory(prefix='claude-ui-') as tmp:
                sock = socket.socket(); sock.bind(('127.0.0.1', 0)); port = sock.getsockname()[1]; sock.close()
                command = ([sys.executable, 'server.py', '--data-file', str(Path(tmp)/'tasks.json')] if flavor == 'full'
                           else [sys.executable, 'app.py', '--db', str(Path(tmp)/'tasks.sqlite3')]) + ['--port', str(port)]
                with (out / f'{flavor}-{variant}-server.log').open('w') as log:
                    proc = subprocess.Popen(command, cwd=root, stdout=log, stderr=log)
                    try:
                        url = f'http://127.0.0.1:{port}'
                        for _ in range(100):
                            try:
                                with urlopen(url, timeout=.2): break
                            except OSError: time.sleep(.05)
                        page = browser.new_page(viewport={'width':1280,'height':900})
                        page.goto(url)
                        title = page.locator('#task-title' if flavor == 'full' else '#title')
                        add = page.locator('#add-button' if flavor == 'full' else '#add')
                        expect(add).to_be_enabled()
                        checks = {}
                        add.click()
                        checks['blank_input_marked_invalid'] = title.get_attribute('aria-invalid') == 'true'
                        checks['error_associated'] = 'error' in (title.get_attribute('aria-describedby') or '').split()
                        title.fill('<b id="literal-probe">検証</b>'); add.click()
                        rows = page.locator('#task-list > li'); expect(rows).to_have_count(1)
                        expect(add).to_be_enabled()
                        checks['added_action_feedback'] = '追加' in page.locator('#status').inner_text()
                        checks['literal_rendering_preserved'] = page.locator('#literal-probe').count() == 0
                        checks['valid_input_clears_error_state'] = title.get_attribute('aria-invalid') is None
                        rows.first.locator('input').click(); expect(rows.first.locator('input')).to_be_checked()
                        expect(add).to_be_enabled()
                        checks['completed_state_feedback'] = '完了にしました' in page.locator('#status').inner_text()
                        page.screenshot(path=str(out/f'{flavor}-{variant}-desktop.png'), full_page=True)
                        page.reload(); expect(rows).to_have_count(1); expect(rows.first.locator('input')).to_be_checked()
                        checks['backend_reload_preserved'] = True
                        rows.first.locator('input').click(); expect(rows.first.locator('input')).not_to_be_checked()
                        expect(add).to_be_enabled()
                        checks['incomplete_state_feedback'] = '未完了に戻しました' in page.locator('#status').inner_text()
                        checks['atomic_live_region'] = page.locator('#status').get_attribute('aria-atomic') == 'true'
                        add.click()
                        checks['validation_clears_previous_success'] = page.locator('#status').inner_text() == ''
                        page.set_viewport_size({'width':390,'height':844})
                        checks['mobile_no_overflow'] = page.evaluate('document.documentElement.scrollWidth <= innerWidth')
                        page.screenshot(path=str(out/f'{flavor}-{variant}-mobile.png'), full_page=True)
                        results.append({'flavor':flavor,'variant':variant,'checks':checks})
                        page.close()
                    finally:
                        proc.terminate(); proc.wait(timeout=10)
    browser.close()
(out/'import-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2)+'\n')
print(json.dumps(results, ensure_ascii=False))
assert all(all(row['checks'].values()) for row in results if row['variant']=='claude-ui')
