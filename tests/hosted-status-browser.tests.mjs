// Run with SDD_PLAYWRIGHT_MODULE pointing to an installed Playwright ESM entry.
const { chromium } = await import(process.env.SDD_PLAYWRIGHT_MODULE || 'playwright');
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
const repo = fileURLToPath(new URL('../', import.meta.url));
const output = process.env.SDD_BROWSER_OUTPUT || '/tmp/sdd-dashboard-browser';
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawn, execFileSync } from 'node:child_process';
import assert from 'node:assert/strict';
mkdirSync(output,{recursive:true});
const entry=resolve(repo,'mcp/sdd-forge-mcp/dist/index.js');
const root=mkdtempSync(join(tmpdir(),'sdd-browser-'));
mkdirSync(join(root,'specs/demo'),{recursive:true});
writeFileSync(join(root,'AGENTS.md'),'# AGENTS\n\n## Active Spec Directories\n\n- `specs/demo/`\n');
writeFileSync(join(root,'specs/demo/requirements.md'),'# Requirements\nSpec-Review-Status: Pending\n');
const tasks=(title='First',status='Planned')=>`# Tasks\nTask-Review-Status: Pending\n\n## T-001 ${title}\nApproval: Approved\nStatus: ${status}\nRisk: low\nRelease: v1\n\nText <script>window.injected=true</script>\n`;
const file=join(root,'specs/demo/tasks.md');writeFileSync(file,tasks());
const child=spawn('node',[entry,'--root',root,'--dashboard']);
const url=await new Promise((resolve,reject)=>{let stderr='';child.stderr.on('data',b=>{stderr+=b;const m=stderr.match(/Read-only status view: (http[^\s]+)/);if(m)resolve(m[1])});child.on('exit',code=>reject(new Error('server exited '+code)));});
const browser=await chromium.launch({executablePath:process.env.SDD_CHROMIUM || '/usr/bin/chromium',headless:true,args:['--no-sandbox']});
const page=await browser.newPage({viewport:{width:1440,height:950}});const errors=[];page.on('pageerror',e=>errors.push(e.message));const checks=[];
try{
 await page.goto(url);await page.locator('#freshness[data-state=live]').waitFor();
 for(const [v,label] of Object.entries({overview:'概要',timeline:'タイムライン',backlog:'バックログ',board:'ボード',list:'一覧',releases:'リリース'})){
  await page.locator('nav a[href="#'+v+'"]').click();await page.locator('#title').filter({hasText:label}).waitFor();assert.ok((await page.locator('#content').innerText()).length>0);checks.push('view:'+v);
 }
 await page.locator('nav a[href="#board"]').click();await page.locator('.card').filter({hasText:'First'}).focus();await page.keyboard.press('Enter');await page.locator('dialog[open]').waitFor();assert.equal(await page.evaluate(()=>window.injected),undefined);await page.keyboard.press('Escape');assert.equal(await page.locator('dialog[open]').count(),0);checks.push('detail-safe-text-and-keyboard');
 await page.locator('#search').fill('not found');assert.equal(await page.locator('.card').count(),0);await page.locator('#search').fill('First');assert.equal(await page.locator('.card').count(),1);await page.locator('#search').fill('');checks.push('search');
 await page.locator('#feature').selectOption('demo');await page.reload();await page.locator('#freshness[data-state=live]').waitFor();assert.equal(await page.locator('#feature').inputValue(),'demo');assert.equal(new URL(page.url()).hash,'#board');checks.push('reload-selection');
 await page.evaluate(()=>localStorage.setItem('sdd-dashboard:'+location.pathname,'null'));await page.reload();await page.locator('#freshness[data-state=live]').waitFor();assert.equal(await page.locator('#feature').inputValue(),'');checks.push('corrupt-preferences-recovery');
 await page.locator('#filter').selectOption('Planned');writeFileSync(file,tasks('Moved','In Progress'));
 await page.locator('.card').filter({hasText:'Moved'}).waitFor({timeout:16000});assert.equal(await page.locator('#filter').inputValue(),'');checks.push('live-update-and-removed-filter');
 const before=await page.evaluate(async()=>await(await fetch('api/dashboard')).json());
 writeFileSync(file,'broken file');await page.locator('#freshness[data-state=error]').waitFor({timeout:16000});assert.equal(await page.locator('.card').filter({hasText:'Moved'}).count(),1);const failed=await page.evaluate(async()=>await(await fetch('api/dashboard')).json());assert.equal(failed.checkedAt,before.checkedAt);checks.push('parse-failure-retains-last-good');
 writeFileSync(file,tasks('Recovered','In Progress'));await page.locator('.card').filter({hasText:'Recovered'}).waitFor({timeout:16000});await page.locator('#freshness[data-state=live]').waitFor();checks.push('recovery');
 await page.screenshot({path:join(output,'board-desktop.png'),fullPage:true});
 await page.setViewportSize({width:390,height:844});await page.locator('#mobile-feature').selectOption('demo');await page.locator('nav a[href="#list"]').click();await page.locator('#content button').first().click();await page.locator('dialog[open]').waitFor();await page.screenshot({path:join(output,'detail-mobile.png'),fullPage:true});await page.locator('#close').click();checks.push('mobile');
 await page.route('**/api/dashboard',async route=>{const stale={...failed,error:null,attemptedAt:new Date().toISOString(),checkedAt:new Date(Date.now()-61000).toISOString()};await route.fulfill({json:stale})});await page.locator('#refresh').click();await page.locator('#freshness[data-state=stale]').waitFor();checks.push('stale-source-with-live-http');
 const artifact=await browser.newPage();
 const artifactHtml=execFileSync('node',[entry,'--root',root,'--dashboard-html','--parent-service','claude'],{encoding:'utf8',stdio:['ignore','pipe','ignore']});
 await artifact.route(url,route=>route.fulfill({contentType:'text/html',body:artifactHtml}));
 await artifact.goto(url);await artifact.locator('#freshness[data-state=error]').waitFor();assert.ok((await artifact.locator('#freshness').innerText()).includes('未接続'));
 await artifact.evaluate(()=>{window.sddDashboardRead=async()=>await(await fetch('api/dashboard')).json()});
 await artifact.locator('#refresh').click();await artifact.locator('#freshness[data-state=live]').waitFor();
 await artifact.locator('nav a[href="#board"]').click();await artifact.locator('.card').filter({hasText:'Recovered'}).waitFor();
 await artifact.evaluate(()=>{window.sddDashboardRead=async()=>({schema:'sdd-dashboard/v1',data:{tasks:[{}]}})});
 await artifact.locator('#refresh').click();await artifact.locator('#freshness[data-state=error]').waitFor();assert.equal(await artifact.locator('.card').filter({hasText:'Recovered'}).count(),1);
 checks.push('artifact-adapter-not-native-host:missing-connected-malformed');await artifact.close();
 await page.unroute('**/api/dashboard');child.kill();await page.locator('#refresh').click();await page.locator('#freshness[data-state=error]').waitFor();assert.ok((await page.locator('#content').innerText()).includes('Moved'));checks.push('disconnect-keeps-data');
 assert.deepEqual(errors,[]);console.log(JSON.stringify({checks,pageErrors:errors,screenshots:['board-desktop.png','detail-mobile.png']},null,2));
}finally{await browser.close();child.kill();rmSync(root,{recursive:true,force:true})}
