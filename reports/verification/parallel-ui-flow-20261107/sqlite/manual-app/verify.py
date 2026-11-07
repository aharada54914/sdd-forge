import json
import os
from pathlib import Path
import sqlite3
import subprocess
import time
from urllib.request import urlopen, Request
from urllib.error import HTTPError
from playwright.sync_api import sync_playwright

root=Path(__file__).parent
# Test uses its own database, preserving the interactive application's data.
db=root/'test.sqlite3'
if db.exists(): db.unlink()
env={**os.environ,'TASK_DB':str(db),'PORT':'8133'}
log=(root/'server.log').open('w')
def start():
    proc=subprocess.Popen(['python3',str(root/'app.py')],env=env,stdout=log,stderr=log)
    for _ in range(100):
        try:
            urlopen('http://127.0.0.1:8133/api/tasks').close()
            return proc
        except OSError: time.sleep(.05)
    raise RuntimeError('Server failed to start')
proc=start()
try:
    with sync_playwright() as p:
        browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
        page=browser.new_page(viewport={'width':1000,'height':720})
        errors=[]
        page.on('pageerror',lambda e:errors.append(str(e)))
        page.goto('http://127.0.0.1:8133')
        page.get_by_role('textbox',name='タスク名').fill('SQLite永続化テスト')
        page.get_by_role('button',name='追加',exact=True).click()
        page.get_by_text('SQLite永続化テスト',exact=True).wait_for()
        page.get_by_role('checkbox').check()
        page.wait_for_function("document.querySelector('li span').className==='done'")
        with sqlite3.connect(db) as connection:
            assert connection.execute('SELECT title,done FROM tasks').fetchall()==[('SQLite永続化テスト',1)]
        proc.terminate();proc.wait();proc=start()
        page.reload()
        page.get_by_text('SQLite永続化テスト',exact=True).wait_for()
        assert page.get_by_role('checkbox').is_checked()
        page.screenshot(path=str(root/'sqlite-desktop.png'),full_page=True)
        page.set_viewport_size({'width':390,'height':844})
        assert page.evaluate('document.documentElement.scrollWidth <= innerWidth')
        page.screenshot(path=str(root/'sqlite-mobile.png'),full_page=True)
        page.get_by_role('button',name='SQLite永続化テストを削除').click()
        page.get_by_text('タスクはありません',exact=True).wait_for()
        title="<img src=x onerror=alert(1)> '; DROP TABLE tasks; --"
        page.get_by_role('textbox',name='タスク名').fill(title)
        page.get_by_role('button',name='追加',exact=True).click()
        page.get_by_text(title,exact=True).wait_for()
        assert page.locator('li img').count()==0
        try:
            urlopen(Request('http://127.0.0.1:8133/api/tasks',data=b'{"title":" "}',headers={'Content-Type':'application/json'}))
            raise AssertionError('Invalid title accepted')
        except HTTPError as error: assert error.code==400
        assert not errors,errors
        browser.close()
    result={'ui_add':True,'ui_complete':True,'ui_delete':True,'sqlite_persistence_after_restart':True,'mobile_no_overflow':True,'xss_literal_text':True,'sql_injection_literal_text':True,'invalid_title_400':True,'page_errors':errors}
    (root/'results.json').write_text(json.dumps(result,indent=2))
    print(json.dumps(result))
finally:
    proc.terminate();proc.wait();log.close()
