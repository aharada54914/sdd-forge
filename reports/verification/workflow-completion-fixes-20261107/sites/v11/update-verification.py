from pathlib import Path
import datetime,hashlib,html,json,re
base=Path('/workspace/.tools/sdd-forge-dev/verification-workspace')
site=Path('/workspace/sites/sdd-forge-status-audit/.sites-checkout')
rows=[]
def task_gate(root,feature,task_id,lite):
 try:
  if lite:
   relative=f'reports/quality-gate/{task_id}.md'
  else:
   bundle=json.loads((root/'specs'/feature/'verification'/f'{task_id}.evidence.json').read_text())
   if bundle.get('task_id')!=task_id or bundle.get('feature')!=feature or bundle.get('review_verdict',{}).get('verdict')!='PASS':return None
   relative=bundle['quality_report']
  gate=(root/relative).resolve()
  if not gate.is_relative_to((root/'reports/quality-gate').resolve()):return None
  raw=gate.read_bytes();body=raw.decode()
  if not re.search(r'(?m)^VERDICT:\s*PASS\s*$',body) or not re.search(r'(?m)^Task ID:\s*'+re.escape(task_id)+r'\s*$',body):return None
  if not lite:
   if not any(a.get('path')==relative and a.get('sha256')==hashlib.sha256(raw).hexdigest() for a in bundle.get('artifacts',[])):return None
  return relative
 except (OSError,ValueError,KeyError,TypeError,AttributeError):return None
for mode,folder,feature in [('Lite','lite-task-board-fixed','task-board'),('Full','full-task-board-fixed','task-board'),('Full + SQLite','sqlite-task-board-fixed','sqlite-task-board')]:
 root=base/folder
 task=root/'specs'/feature/'tasks.md'
 task_text=task.read_text() if task.exists() else ''
 states=re.findall(r'^Status: (.+)$',task_text,re.M)
 task_ids=re.findall(r'^## (T-\d+)\b',task_text,re.M)
 gates=[task_gate(root,feature,task_id,mode=='Lite') for task_id in task_ids]
 gate_pass=bool(gates) and all(gates)
 done=bool(states) and len(states)==len(task_ids) and all(s=='Done' for s in states) and gate_pass
 reviews=sorted((root/'reports/spec-review'/feature).glob('attempt-*/round-*/integrated-verdict.json'))
 latest=json.loads(reviews[-1].read_text()) if reviews else None
 requirements=(root/'specs'/feature/'requirements.md').read_text()
 design=(root/'specs'/feature/'design.md').read_text()
 task_text=task.read_text() if task.exists() else ''
 phase=('完了' if done else 'タスクレビュー' if states and 'Task-Review-Status: Passed' not in task_text else '実装・品質確認' if states else '実装設計レビュー' if 'Spec-Review-Status: Passed' in requirements else '仕様レビュー')
 files=list((root/'reports/visual-evidence').rglob('*.png'))
 rows.append({'mode':mode,'phase':phase,'state':'Done / PASS' if done else '進行中','tasks':states,'screenshots':len(files),'detail':('独立ゲートと実ブラウザー検証を完了。' if done else '独立レビューの指摘を修正し、再検証しています。'),'qualityReports':gates,'completedTasks':sum(s=='Done' and bool(g) for s,g in zip(states,gates)),'evidence':'reports/quality-gate/' if done else 'reports/spec-review/'+feature+'/'})
now=datetime.datetime.now(datetime.timezone.utc)
observed=now.isoformat()
display_time=now.astimezone(datetime.timezone(datetime.timedelta(hours=9))).strftime('%Y/%m/%d %H:%M JST')
data={'schema':'sdd-verification-progress/v1','observedAt':observed,'automatic':False,'sessions':rows,'provider':'ImageGenの実生成参照を採用。Claude Design / DesignSyncの接続成功ではありません。'}
(site/'data').mkdir(exist_ok=True)
(site/'data/verification-progress.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
cards=''.join('<article class="verification-card"><h3>'+html.escape(r['mode'])+'</h3><strong>'+html.escape(r['state'])+'</strong><p>'+html.escape(r['phase']+' — '+r['detail'])+'</p><p class="muted">完了: '+str(r['completedTasks'])+'/'+str(len(r['tasks']))+'タスク · 画面証拠: '+str(r['screenshots'])+'枚</p></article>' for r in rows)
section='<section id="verification-progress" aria-labelledby="verification-heading" class="panel"><h2 id="verification-heading">3セッションの実動作検証</h2><p>取得時点: <time datetime="'+observed+'">'+display_time+'</time> · 保存した進捗です。自動更新ではありません。</p><div class="verification-grid">'+cards+'</div><p>'+html.escape(data['provider'])+'</p><p>テスト専用の承認fixtureを使用。通常の本番承認とは区別しています。</p><a href="https://github.com/aharada54914/sdd-forge/tree/work/20261107-194329-fix-workflow-completion" target="_blank" rel="noopener noreferrer">本体修正と検証記録</a></section>'
p=site/'worker/index.js';source=p.read_text();m=re.search(r'const page = (".*");\n',source);page=json.loads(m[1]);page=re.sub(r'<section id="verification-progress".*?</section>','',page,flags=re.S)
page=page.replace('<div id="content" aria-live="polite"></div>','<div id="content" aria-live="polite"></div>'+section)
css='.verification-grid{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:16px}.verification-card{border:1px solid #dfe1e6;border-radius:8px;padding:16px;overflow-wrap:anywhere}.verification-card h3{margin-top:0}@media(max-width:760px){.verification-grid{grid-template-columns:1fr}}'
if '.verification-grid{' not in page:page=page.replace('</style>',css+'</style>')
source=source[:m.start(1)]+json.dumps(page,ensure_ascii=False)+source[m.end(1):];p.write_text(source)
print(json.dumps(data,ensure_ascii=False))
