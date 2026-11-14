from playwright.sync_api import sync_playwright,expect
from pathlib import Path
import json
root=Path(__file__).parent
results=[]
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
 page=browser.new_page(viewport={'width':1440,'height':1000});errors=[]
 page.on('pageerror',lambda e:errors.append(str(e)))
 page.goto('http://127.0.0.1:8790');expect(page.locator('#project')).to_contain_text('Sitesローカル機能試験')
 for key,label in [('overview','概要'),('timeline','タイムライン'),('backlog','バックログ'),('board','ボード'),('list','一覧'),('releases','リリース')]:
  page.locator('#tabs').get_by_role('link',name=label,exact=True).click();expect(page.locator('#title')).to_have_text(label);assert page.locator('#content').inner_text();results.append('view:'+key)
 page.locator('#tabs').get_by_role('link',name='一覧',exact=True).click();expect(page.locator('tbody tr')).to_have_count(5)
 page.locator('#search').fill('T-001');expect(page.locator('tbody tr')).to_have_count(1);page.reload();expect(page.locator('#search')).to_have_value('T-001');results.append('search and preferences persist')
 page.locator('#search').fill('');page.locator('#filter').select_option('Blocked');expect(page.locator('tbody tr')).to_have_count(1);expect(page.locator('tbody')).to_contain_text('T-003');page.locator('#filter').select_option('');results.append('status filter')
 page.locator('#feature').select_option('full');expect(page.locator('#content')).to_contain_text('条件に一致する課題はありません');page.locator('#feature').select_option('');results.append('feature filter and empty state')
 page.locator('tbody').get_by_role('button',name='T-001',exact=True).click();expect(page.locator('#detail')).to_be_visible();expect(page.locator('#detail-content')).to_contain_text('<img src=x onerror=alert(1)>');assert page.locator('#detail-content img').count()==0;page.locator('#close').click();results.append('details, close, safe text rendering')
 # Native five-second poll must observe a new publication, without reload or manual refresh.
 r=page.request.post('http://127.0.0.1:8790/__qa/update',data={'title':'自動反映確認'});assert r.status==200,(r.status,r.text())
 expect(page.locator('tbody')).to_contain_text('自動反映確認',timeout=9000);results.append('automatic polling update')
 page.locator('#pause').click();r=page.request.post('http://127.0.0.1:8790/__qa/update',data={'title':'再開後の表示'});assert r.status==200,(r.status,r.text())
 page.locator('#refresh').click();expect(page.locator('#freshness')).to_have_attribute('data-state','paused');expect(page.locator('tbody')).not_to_contain_text('再開後の表示');page.locator('#pause').click();expect(page.locator('tbody')).to_contain_text('再開後の表示');results.append('pause, fetch while paused, resume latest')
 page.locator('#activity summary').click();expect(page.locator('#activity-events')).to_contain_text('観測を開始');page.locator('#acknowledge').click();expect(page.locator('#activity-summary')).to_contain_text('未確認 0件');page.reload();expect(page.locator('#activity-summary')).to_contain_text('未確認 0件');results.append('history and acknowledgment persist')
 page.locator('#tabs').get_by_role('link',name='概要',exact=True).click();page.get_by_role('button',name='進行停止 · 1',exact=True).click();expect(page.locator('tbody tr')).to_have_count(1);expect(page.locator('tbody')).to_contain_text('T-003');page.get_by_role('button',name='対応事項の絞り込みを解除').click();results.append('overview attention drilldown and clear')
 page.locator('#tabs').get_by_role('link',name='概要',exact=True).click();page.screenshot(path=str(root/'desktop.png'),full_page=True)
 page.set_viewport_size({'width':390,'height':844});assert page.evaluate('document.documentElement.scrollWidth <= innerWidth');page.locator('#mobile-feature').select_option('sqlite');expect(page.locator('#content')).to_contain_text('SQLite');page.screenshot(path=str(root/'mobile.png'),full_page=True);page.locator('#mobile-feature').select_option('');results.append('mobile layout and feature selector')
 r=page.request.post('http://127.0.0.1:8790/__qa/update',data={'stale':True});assert r.status==200,(r.status,r.text())
 page.locator('#refresh').click();expect(page.locator('#freshness')).to_have_attribute('data-state','stale');results.append('stale source visibly warned')
 page.request.post('http://127.0.0.1:8790/__qa/network',data={'fail':True});page.locator('#refresh').click();expect(page.locator('#freshness')).to_have_attribute('data-state','error');expect(page.locator('#content')).to_contain_text('開発テーマごとの進捗');results.append('network failure retains last content with warning')
 page.request.post('http://127.0.0.1:8790/__qa/network',data={'fail':False});page.locator('#refresh').click();expect(page.locator('#freshness')).to_have_attribute('data-state','stale');results.append('network recovery')
 assert not errors,errors;results.append('no JavaScript errors')
 browser.close()
(root/'browser-results.json').write_text(json.dumps({'scope':'published source served locally, controlled fixtures; not production data','passed':results,'pageErrors':errors},ensure_ascii=False,indent=2))
print(json.dumps({'passed':len(results),'checks':results},ensure_ascii=False))
