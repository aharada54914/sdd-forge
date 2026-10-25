import copy, importlib.util, json, platform, subprocess, sys
from pathlib import Path
from playwright.sync_api import sync_playwright
ROOT=Path('/workspace/sdd-forge'); OUT=Path(__file__).resolve().parent
SCRIPTS=ROOT/'plugins/sdd-quality-loop/scripts';sys.path.insert(0,str(SCRIPTS))
from research_evidence import digest
from research_extraction import extract
spec=importlib.util.spec_from_file_location('fixtures',ROOT/'tests/research-evidence.tests.py');f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f)
quote='字幕の原文 & literal "quote".'
vtt=('WEBVTT\n\n00:01.200 --> 00:03.500\n'+quote+'\n\n00:04.000 --> 00:06.000\nUnquoted later caption.\n').encode()
receipts=[]; artifacts={}
for kind,raw,media in [('subtitle',vtt,'text/vtt'),('plain',b'original\n','text/plain')]:
 directory=OUT/kind;directory.mkdir(exist_ok=True)
 extracted,method,_=extract(raw,media)
 (directory/'original').write_bytes(raw);(directory/'extracted').write_bytes(extracted)
 doc=f.document();source=doc['sources'][0]
 source.update(media_type=media,content_sha256=digest(raw),title='Fixture <script>window.__injected=1</script>')
 source['extraction']=dict(method=method,extracted_sha256=digest(extracted))
 anchor=doc['claims'][0]['citations'][0]['anchor']
 if kind=='subtitle':anchor.update(line_start=2,line_end=2,quote=quote,quote_sha256=digest(quote.encode()))
 snapshots=dict(schema='research-snapshots/v1',feature='sample',snapshots=[dict(source_id='SRC-001',record_revision=1,original='original',extracted='extracted')])
 annotations=dict(schema='research-report-annotations/v1',feature='sample',translations=[dict(claim_id='CLM-001',claim_revision=1,citation=0,quote_sha256=anchor['quote_sha256'],language='ja',text='評価用の訳 <script>window.__injected=2</script>')])
 for name,data in [('records.json',doc),('snapshots.json',snapshots),('annotations.json',annotations)]: (directory/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 args=[sys.executable,str(SCRIPTS/'research-evidence-tools.py')]
 opts=['--file',str(directory/'records.json'),'--snapshots',str(directory/'snapshots.json'),'--snapshot-root',str(directory)]
 check=subprocess.run(args+['check']+opts,capture_output=True,text=True,timeout=20);assert check.returncode==0,check.stderr
 record=json.loads(check.stdout);(directory/'verification.json').write_text(check.stdout)
 assert record['schema']==('source-evidence-result/v2' if kind=='subtitle' else 'source-evidence-result/v1')
 if kind=='subtitle':assert record['results'][0]['time_range']==dict(start_ms=1200,end_ms=3500)
 else:assert 'time_range' not in record['results'][0]
 command=args+['report']+opts+['--annotations',str(directory/'annotations.json'),'--output',str(directory/'report.html')]
 rendered=subprocess.run(command,capture_output=True,text=True,timeout=20);assert rendered.returncode==0,rendered.stderr
 artifacts[kind]=(directory,anchor['quote'],annotations['translations'][0]['text'])
 receipts.append(dict(case=kind,check_exit=check.returncode,report_exit=rendered.returncode,schema=record['schema'],time_range=record['results'][0].get('time_range'),report_sha256=digest((directory/'report.html').read_bytes())))
 if kind=='subtitle':
  original_report=(directory/'report.html').read_bytes()
  for label in ['forged-extracted-time','subtitle-markup']:
   changed=copy.deepcopy(doc)
   if label=='forged-extracted-time':
    fake=extracted.replace(b'1200 3500',b'9000 9500');(directory/'extracted').write_bytes(fake);changed['sources'][0]['extraction']['extracted_sha256']=digest(fake)
   else:
    fake=raw.replace(quote.encode(),b'<script>window.__injected=3</script>');(directory/'original').write_bytes(fake);changed['sources'][0]['content_sha256']=digest(fake)
   (directory/'records.json').write_text(json.dumps(changed,ensure_ascii=False))
   rejected=subprocess.run(command,capture_output=True,text=True,timeout=20)
   preserved=(directory/'report.html').read_bytes()==original_report
   assert rejected.returncode==1 and preserved,(label,rejected.stderr)
   receipts.append(dict(case=label,report_exit=rejected.returncode,prior_report_preserved=preserved,diagnostic=rejected.stderr.strip()))
   (directory/'original').write_bytes(raw);(directory/'extracted').write_bytes(extracted);(directory/'records.json').write_text(json.dumps(doc,ensure_ascii=False,indent=2)+'\n')
browser_checks={};requests=[]
with sync_playwright() as p:
 browser=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox']);version=browser.version
 context=browser.new_context(offline=True,viewport=dict(width=1150,height=800))
 def route(r):
  kind=r.request.url.split('/')[-1].removesuffix('.html')
  if kind in artifacts:r.fulfill(status=200,content_type='text/html; charset=utf-8',body=(artifacts[kind][0]/'report.html').read_bytes())
  else:r.abort()
 context.route('https://fixture.invalid/**',route)
 page=context.new_page();page.on('request',lambda request:requests.append(request.url))
 for kind,(directory,expected_quote,translation) in artifacts.items():
  page.goto('https://fixture.invalid/'+kind+'.html')
  page.locator('summary').click()
  checks=dict(original_click=page.locator('details').evaluate('(e)=>e.open') and page.locator('details blockquote').inner_text()==expected_quote,
   translation_distinct=page.locator('blockquote[lang="ja"]').inner_text()==translation and page.get_by_text('Translation (ja); meaning not verified:',exact=True).is_visible(),
   injection_inert=page.locator('script,img,iframe').count()==0 and page.evaluate('typeof window.__injected === "undefined"'),
   csp_present="default-src 'none'" in page.locator('meta[http-equiv="Content-Security-Policy"]').get_attribute('content'),
   no_cdn=page.locator('script[src],link[href]').count()==0)
  text=page.locator('body').inner_text()
  if kind=='subtitle':checks.update(time_display='00:00:01.200–00:00:03.500' in text,video_limit_explicit='video alignment not independently verified' in text)
  else:checks['legacy_no_subtitle_claim']='Subtitle cue time:' not in text
  assert all(checks.values()),(kind,checks)
  browser_checks[kind]=checks;page.screenshot(path=str(directory/'display.png'),full_page=True)
 context.close();browser.close()
result=dict(schema='subtitle-display-evaluation/v1',runtime=dict(browser='Chromium',version=version,python=sys.version.split()[0],platform=platform.platform()),product_sha256={name:digest((SCRIPTS/name).read_bytes()) for name in ['research_consumers.py','research_extraction.py','research-evidence-tools.py']},cli=receipts,browser_checks=browser_checks,requests=requests,network_scope='Offline browser; exact local report bytes fulfilled by fixture route. No live source fetch or direct file:// test.',limitations=['Actual video synchronization and timestamp accuracy against video were not tested.','Only Linux Chromium was executed.','Plain-cue WebVTT subset tested; richer cue markup is explicitly rejected.'],passed=True)
(OUT/'result.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps(dict(passed=True,browser=version,cli_cases=len(receipts),browser_cases=len(browser_checks))))
