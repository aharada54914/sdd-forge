import functools
import hashlib
import http.server
import json
from pathlib import Path
import threading
from playwright.sync_api import sync_playwright

root = Path(__file__).resolve().parent
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(root))
server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
checks = {}
errors = []
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True, args=['--no-sandbox'])
        page = browser.new_page(viewport={'width': 1280, 'height': 900})
        page.on('pageerror', lambda error: errors.append(str(error)))
        page.goto(f'http://127.0.0.1:{server.server_port}/artifact.html')
        page.locator('#add-task-btn').click()
        checks['blank_error_associated'] = page.locator('#task-name').get_attribute('aria-invalid') == 'true' and bool(page.locator('#task-name-error').inner_text())
        page.locator('#task-name').fill('検証タスク')
        page.locator('#task-name').press('Enter')
        checks['add_keyboard'] = page.locator('#total-tasks').inner_text() == '1'
        checks['add_status'] = '追加' in page.locator('#status-message-area').inner_text()
        page.locator('.task-checkbox').check()
        checks['toggle'] = page.locator('#completed-tasks').inner_text() == '1'
        page.once('dialog', lambda dialog: dialog.dismiss())
        page.locator('.delete-button').click()
        checks['delete_cancel_preserves'] = page.locator('#total-tasks').inner_text() == '1'
        page.once('dialog', lambda dialog: dialog.accept())
        page.locator('.delete-button').click()
        checks['delete'] = page.locator('#total-tasks').inner_text() == '0'
        page.locator('#task-name').fill('<b id="literal-probe">文字列</b>')
        page.locator('#add-task-btn').click()
        checks['untrusted_title_is_literal'] = page.locator('#literal-probe').count() == 0
        page.screenshot(path=str(root / 'artifact-desktop.png'), full_page=True)
        page.set_viewport_size({'width': 390, 'height': 844})
        checks['mobile_no_overflow'] = page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        page.screenshot(path=str(root / 'artifact-mobile.png'), full_page=True)
        page.reload()
        checks['reload_persistence'] = page.locator('#total-tasks').inner_text() == '1'
        browser.close()
finally:
    server.shutdown()
result = {'artifact_sha256': hashlib.sha256((root / 'artifact.html').read_bytes()).hexdigest(), 'checks': checks, 'page_errors': errors, 'interpretation': 'Provider UI source is a disposable reference. Functional checks are actual fresh Chromium interactions; persistence and literal-rendering failures prohibit copying its runtime implementation into the apps.'}
(root / 'artifact-results.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(result, ensure_ascii=False))
