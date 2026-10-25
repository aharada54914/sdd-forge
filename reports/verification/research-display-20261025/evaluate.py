#!/usr/bin/env python3
"""Independent #610 evaluation using authored local fixtures and real Chromium."""
import argparse
import copy
import hashlib
import importlib.util
import json
import platform
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', required=True, type=Path, help='Fresh evidence directory; an existing path is rejected.')
args = parser.parse_args()
OUTPUT = args.output.absolute()
try:
    OUTPUT.mkdir(parents=True, exist_ok=False)
except OSError as exc:
    parser.error(f'cannot create fresh output directory: {exc}')
SCRIPTS = ROOT / 'plugins/sdd-quality-loop/scripts'
sys.path.insert(0, str(SCRIPTS))
from research_evidence import digest
from playwright.sync_api import sync_playwright

spec = importlib.util.spec_from_file_location('fixture', ROOT / 'tests/research-evidence.tests.py')
fixture = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fixture)
inputs = OUTPUT / 'inputs'
inputs.mkdir(exist_ok=True)
quote = 'Quoted fixture: <script>window.__injected=1</script><img src=x onerror="window.__injected=2"> 日本語'
original = ('Author-created context before.\n' + quote + '\nUNQUOTED_PRIVATE_SENTINEL: context after.\n').encode()
alternative = b'Alternative fixture: this contradicts the proposed claim.\n'
(inputs / 'original.txt').write_bytes(original)
(inputs / 'extracted.txt').write_bytes(original)
(inputs / 'alternative.txt').write_bytes(alternative)
doc = fixture.document()
s = doc['sources'][0]
s.update(title='Fixture source <img src=x onerror="window.__injected=3">', content_sha256=digest(original))
s['extraction']['extracted_sha256'] = digest(original)
c = doc['claims'][0]
c.update(statement='Read the evidence; no design approval is asserted.', evidence_status='conflicting')
a = c['citations'][0]['anchor']
a.update(line_start=2, line_end=2, quote=quote, quote_sha256=digest(quote.encode()))
s2 = copy.deepcopy(s)
s2.update(source_id='SRC-002', title='Alternative fixture source', url='https://example.org/alternative', final_url='https://example.org/alternative', content_sha256=digest(alternative))
s2['extraction']['extracted_sha256'] = digest(alternative)
doc['sources'].append(s2)
c2 = copy.deepcopy(c['citations'][0])
c2.update(source_id='SRC-002', relation='contradicts')
c2['anchor'].update(line_start=1, line_end=1, quote=alternative.decode().strip(), quote_sha256=digest(alternative.strip()))
c['citations'].append(c2)
unreached = fixture.claim()
unreached.update(claim_id='CLM-002', statement='Not searched fixture', evidence_status='not-searched', citations=[])
doc['claims'].append(unreached)
s3 = fixture.source()
s3.update(source_id='SRC-003', title='Unavailable source (fixture)', url='https://example.org/unavailable', retrieval_status='unreachable', content_sha256=None, final_url=None, retrieved_at=None, media_type=None, extraction=None)
doc['sources'].append(s3)
c3 = fixture.claim()
c3.update(claim_id='CLM-003', statement='Unconfirmed fixture', evidence_status='unreachable')
c3['citations'][0].update(source_id='SRC-003', anchor=None)
doc['claims'].append(c3)
snapshots = dict(schema='research-snapshots/v1', feature='sample', snapshots=[
 dict(source_id='SRC-001', record_revision=1, original='original.txt', extracted='extracted.txt'),
 dict(source_id='SRC-002', record_revision=1, original='alternative.txt', extracted='alternative.txt')])
annotations = dict(schema='research-report-annotations/v1', feature='sample', translations=[dict(claim_id='CLM-001', claim_revision=1, citation=0, quote_sha256=a['quote_sha256'], language='ja', text='評価用の訳。<script>window.__injected=4</script> 原文とは区別する。')])
def write(name, value):
    (inputs / name).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
write('records.json', doc)
write('snapshots.json', snapshots)
write('annotations.json', annotations)
output = OUTPUT / 'report.html'
command = [sys.executable, str(SCRIPTS / 'research-evidence-tools.py'), 'report', '--file', str(inputs / 'records.json'), '--snapshots', str(inputs / 'snapshots.json'), '--snapshot-root', str(inputs), '--annotations', str(inputs / 'annotations.json'), '--output', str(output)]
run = subprocess.run(command, capture_output=True, text=True, timeout=20)
assert run.returncode == 0, run.stderr
valid_hash = digest(output.read_bytes())
negative = []
for case in ['false-quote', 'stale-hash', 'missing-original', 'missing-snapshot', 'stale-source', 'stale-translation']:
    changed = copy.deepcopy(doc)
    changed_snapshots = copy.deepcopy(snapshots)
    changed_annotations = copy.deepcopy(annotations)
    if case == 'false-quote':
        anchor = changed['claims'][0]['citations'][0]['anchor']
        anchor.update(quote='Invented quote', quote_sha256=digest(b'Invented quote'))
    elif case == 'stale-hash': changed['sources'][0]['content_sha256'] = '0'*64
    elif case == 'missing-original': (inputs / 'original.txt').unlink()
    elif case == 'missing-snapshot': changed_snapshots['snapshots'].pop(0)
    elif case == 'stale-source': changed['sources'][0].update(currency_status='stale', currency_note='Synthetic obsolete source')
    elif case == 'stale-translation': changed_annotations['translations'][0]['quote_sha256'] = '0'*64
    write('records.json', changed); write('snapshots.json', changed_snapshots); write('annotations.json', changed_annotations)
    result = subprocess.run(command, capture_output=True, text=True, timeout=20)
    preserved = digest(output.read_bytes()) == valid_hash
    negative.append(dict(case=case, exit_code=result.returncode, diagnostic=result.stderr.strip(), prior_report_preserved=preserved))
    assert result.returncode == 1 and preserved, negative[-1]
    (inputs / 'original.txt').write_bytes(original)
write('records.json', doc); write('snapshots.json', snapshots); write('annotations.json', annotations)

requests, denied, dialogs = [], [], []
report_url = 'https://report.fixture.invalid/research-report.html'
with sync_playwright() as playwright:
    browser = playwright.chromium.launch(executable_path='/usr/bin/chromium', headless=True, args=['--no-sandbox'])
    browser_version = browser.version
    context = browser.new_context(offline=True, viewport=dict(width=1200, height=1100))
    def route(request):
        if request.request.url == report_url:
            request.fulfill(status=200, content_type='text/html; charset=utf-8', body=output.read_bytes())
        elif request.request.url == s['url']:
            request.fulfill(status=200, content_type='text/plain; charset=utf-8', body=original)
        else:
            denied.append(request.request.url)
            request.abort()
    context.route('https://**/*', route)
    page = context.new_page()
    page.on('request', lambda request: requests.append(dict(url=request.url, resource_type=request.resource_type)))
    page.on('dialog', lambda dialog: (dialogs.append(dialog.message), dialog.dismiss()))
    page.goto(report_url)
    page.wait_for_load_state('load')
    checks = {}
    checks['offline_report_loaded'] = page.title() == 'Research evidence'
    checks['no_external_assets'] = all(item['url'] == report_url for item in requests)
    checks['no_active_injected_elements'] = page.locator('script,img,iframe,style,link').count() == 0
    checks['no_script_effect_or_dialog'] = page.evaluate('typeof window.__injected === "undefined"') and not dialogs
    checks['reference_only_no_full_text'] = 'UNQUOTED_PRIVATE_SENTINEL' not in page.locator('body').inner_text()
    details = page.locator('details').first
    checks['original_initially_collapsed'] = not details.evaluate('(node) => node.open')
    checks['translation_distinct'] = page.locator('blockquote[lang="ja"]').inner_text() == annotations['translations'][0]['text'] and page.get_by_text('Translation (ja); meaning not verified:', exact=True).is_visible()
    page.get_by_text('Original excerpt, lines 2–2', exact=True).click()
    checks['click_opens_exact_original_range'] = details.evaluate('(node) => node.open') and details.locator('blockquote').inner_text() == quote
    page.locator('summary').first.focus()
    page.keyboard.press('Enter')
    checks['keyboard_toggles_original'] = not details.evaluate('(node) => node.open')
    page.keyboard.press('Enter')
    checks['conflicting_and_unreached_explicit'] = page.get_by_text('Disagreement: this citation contradicts the claim.', exact=True).is_visible() and page.get_by_text('Unreached: no source citations.', exact=True).is_visible()
    checks['unconfirmed_labeled_without_fresh_proof'] = page.get_by_text('Original unavailable; no fresh verification claimed.', exact=True).is_visible() and 'meaning: unassessed' in page.locator('body').inner_text()
    checks['no_absolute_snapshot_path_exposed'] = str(inputs) not in page.locator('body').inner_text()
    page.screenshot(path=str(OUTPUT / 'expanded-report.png'), full_page=True)
    link = page.locator('a').first
    checks['source_href_matches_record'] = link.get_attribute('href') == s['url']
    link.click()
    page.wait_for_url(s['url'])
    checks['source_click_routes_to_exact_fixture_original'] = page.locator('body').inner_text().strip() == original.decode().strip()
    checks['no_unexpected_network'] = not denied
    assert all(checks.values()), checks
    context.close(); browser.close()
receipt = dict(schema='independent-research-display-evaluation/v1', issue=610, runtime=dict(python=sys.version.split()[0], platform=platform.platform(), browser='Chromium', browser_version=browser_version, executable='/usr/bin/chromium', headless=True), file_url_observation='not-run: this replay tests exact local HTML bytes through an offline intercepted fixture URL; it does not attempt file:// navigation.', fixture_scope='Author-created local text only; no third-party originals or live acquisition. Source-link navigation fulfilled from exact local fixture bytes with browser offline.', product_sha256={name:digest((SCRIPTS/name).read_bytes()) for name in ['research-evidence-tools.py','research_consumers.py','research_evidence.py','research_extraction.py']}, report_sha256=valid_hash, browser_checks=checks, negative_regeneration=negative, network_requests=[dict(url=item['url'].replace(report_url,'report.html'), resource_type=item['resource_type']) for item in requests], unsupported=['Direct file:// navigation (not run by this replay)' , 'Native Windows/macOS browser execution','External live acquisition and remote source availability','Shared-store per-user ACL enforcement','PDF multicolumn and video timestamp rendering (unsupported extractor/anchor formats)','Human screen-reader evaluation and translation meaning/accuracy'], passed=True)
(OUTPUT / 'result.json').write_text(json.dumps(receipt, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(dict(passed=True, browser_version=browser_version, browser_checks=len(checks), negative_regeneration=len(negative))))
