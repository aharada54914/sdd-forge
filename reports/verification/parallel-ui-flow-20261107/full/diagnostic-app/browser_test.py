import json
from pathlib import Path
from playwright.sync_api import sync_playwright, expect

root=Path(__file__).resolve().parent
with sync_playwright() as p:
    browser=p.chromium.launch(headless=True, executable_path="/usr/bin/chromium", args=["--no-sandbox"])
    page=browser.new_page(viewport={'width':1000,'height':800})
    errors=[]
    page.on('pageerror',lambda e: errors.append(str(e)))
    page.goto('http://127.0.0.1:8766')
    page.get_by_label('タスク名',exact=True).fill('検証タスク')
    page.get_by_role('button',name='追加',exact=True).click()
    expect(page.get_by_text('検証タスク',exact=True)).to_be_visible()
    page.get_by_role('checkbox').check()
    page.reload()
    expect(page.get_by_role('checkbox')).to_be_checked()
    assert json.loads((root/'tasks.json').read_text())[0]['done'] is True
    page.screenshot(path=str(root/'ui.png'),full_page=True)
    page.get_by_role('button',name='検証タスクを削除').click()
    expect(page.get_by_text('タスクはありません',exact=True)).to_be_visible()
    page.reload()
    expect(page.get_by_text('タスクはありません',exact=True)).to_be_visible()
    assert json.loads((root/'tasks.json').read_text()) == []
    response=page.request.post('http://127.0.0.1:8766/api/tasks',data={'title':' '})
    assert response.status==400
    assert not errors,errors
    browser.close()
print(json.dumps({'status':'PASS','checks':['UI add','UI toggle','reload persistence','JSON disk persistence','UI delete','delete persistence','empty title rejected','no browser errors'],'scope':'diagnostic app only; SDD full flow blocked before specs'},indent=2))
