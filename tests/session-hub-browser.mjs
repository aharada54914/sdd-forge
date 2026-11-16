/** Real UI journey. Every process and data directory belongs to this invocation. */
import { mkdtemp, mkdir, rm, writeFile, readFile } from 'node:fs/promises';
import { join, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { randomBytes, createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import assert from 'node:assert/strict';
import { startLocal } from '../plugins/sdd-ship/session-hub/local.mjs';
import { apiClient } from '../plugins/sdd-ship/session-hub/api.mjs';
import { digest } from '../plugins/sdd-ship/session-hub/http.mjs';
import { runOne } from '../plugins/sdd-ship/session-hub/runner.mjs';
const { chromium } = await import(process.env.SDD_PLAYWRIGHT_MODULE || 'playwright');
const output = resolve(process.env.SDD_BROWSER_OUTPUT || '/tmp/sdd-session-hub-evidence');
await mkdir(output,{recursive:true});
const directory = await mkdtemp(join(tmpdir(),'sdd-hub-browser-'));
const ownerToken=randomBytes(32).toString('hex'), sessionToken=randomBytes(32).toString('hex');
const checks=[], errors=[]; let host,browser;
const inputs = execFileSync('git',['ls-files','--cached','--others','--exclude-standard','plugins/sdd-ship/session-hub','scripts/merge-readiness.py','tests/session-hub-browser.mjs'],{encoding:'utf8'}).trim().split('\n');
const inputHashes = Object.fromEntries(await Promise.all(inputs.map(async file => [file,createHash('sha256').update(await readFile(file)).digest('hex')])));
const evidence = status => ({status,checks,errors,inputHashes,exitCode:status === 'PASS' ? 0 : 1,revision:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim()});
try {
  host=await startLocal({directory,project:'demo',ownerToken});
  const owner=apiClient({url:host.url,project:'demo',token:ownerToken});
  let state=await owner.read();
  assert.equal(state.questions.length,0); checks.push('doctor-empty-hub');
  state=await owner.command(state,'register',{id:'worker',label:'実装セッション',tokenHash:await digest(sessionToken)});
  const worker=apiClient({url:host.url,project:'demo',token:sessionToken});
  await worker.command(await worker.read(),'ask',{id:'design',sessionId:'worker',title:'表示する部品を選んでください <script>',expiresAt:Date.now()+3600000,
    options:[{id:'a',label:'強調ボタン',preview:{storyId:'hub-choice--variants',version:'1',variant:'primary'}},{id:'b',label:'標準ボタン',preview:{storyId:'hub-choice--variants',version:'1',variant:'secondary'}}]});
  browser=await chromium.launch({executablePath:process.env.SDD_CHROMIUM || '/usr/bin/chromium',headless:true,args:['--no-sandbox']});
  const page=await browser.newPage({viewport:{width:1280,height:960}});page.on('pageerror',e=>errors.push(e.message));
  await page.goto(host.url+'/hub'); await page.locator('#login:not([hidden])').waitFor();
  await page.locator('#token').fill(ownerToken); await page.locator('#login button').click();
  await page.getByRole('button',{name:'強調ボタン',exact:true}).waitFor();
  await page.screenshot({path:join(output,'questions-desktop.png'),fullPage:true});
  await page.getByRole('button',{name:'標準ボタン',exact:true}).click();
  await page.locator('#filter').selectOption('answered');
  await page.getByRole('button',{name:'標準ボタン',exact:true}).waitFor();
  assert.equal((await worker.read()).questions[0].answer.optionId,'b');
  checks.push('login-real-component-choice-and-delivery');
  state=await worker.read();await worker.command(state,'receive',{id:'design',requestId:state.questions[0].answer.requestId});
  await page.locator('#refresh').click();await page.locator('#filter').selectOption('received');
  await page.getByText('実装セッション · 受領済み',{exact:true}).waitFor();checks.push('session-receipt-visible');
  await page.locator('#away').click();await page.getByText('有効：ワーカーが空き資源を確認して実行します',{exact:true}).waitFor();
  await page.locator('#command').fill('verify');await page.locator('#job-title').fill('離席中の検証');await page.locator('#enqueue button').click();
  await page.locator('#jobs').getByText('離席中の検証 · 実行待ち',{exact:false}).waitFor();
  const effect=join(directory,'verified');
  assert.equal(await runOne({url:host.url,project:'demo',token:sessionToken,sessionId:'worker',minFreeMb:0,maxLoad:100,
    commands:{verify:{argv:[process.execPath,'-e',"require('node:fs').writeFileSync(process.argv[1],'verified')",effect],cwd:directory,timeoutMs:5000}}}),true);
  assert.equal(await readFile(effect,'utf8'),'verified');
  await page.locator('#refresh').click();await page.locator('#jobs').getByText('離席中の検証 · 成功',{exact:true}).waitFor();checks.push('ui-approved-job-to-real-worker-side-effect');
  state=await owner.read();
  await owner.command(state,'register',{id:'existing-codex',label:'既存Codex会話',tokenHash:await digest(randomBytes(32).toString('hex')),transport:'codex',destination:'11111111-2222-4333-8444-555555555555'});
  await page.locator('#refresh').click();await page.locator('#push-session option').filter({hasText:'既存Codex会話'}).waitFor({state:'attached'});
  await page.locator('#message-text').fill('この既存会話に検証メッセージを送る');await page.locator('#send-message button').click();
  await page.locator('#messages').getByText('existing-codex · 実行待ち',{exact:true}).waitFor();
  const message=(await owner.read()).messages.at(-1);assert.equal(message.destination,'11111111-2222-4333-8444-555555555555');
  assert.equal(message.text,'この既存会話に検証メッセージを送る');checks.push('ui-message-targets-registered-existing-conversation');
  await page.setViewportSize({width:390,height:844});
  await page.screenshot({path:join(output,'hub-mobile.png'),fullPage:true});
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);checks.push('mobile-no-horizontal-overflow');
  await page.route('**/api/hub',r=>r.abort());await page.locator('#refresh').click();await page.getByText(/接続できません。最後の正常データ/).waitFor();checks.push('failed-read-retains-last-good-state');
  assert.deepEqual(errors,[]);
  const artifact=execFileSync(process.execPath,['plugins/sdd-ship/session-hub/artifact.mjs'],{encoding:'utf8'});
  await page.unroute('**/api/hub');await page.setContent(artifact);await page.getByText(/Artifactの読取コネクタが未接続です/).waitFor();checks.push('artifact-missing-native-connector-fails-visibly');
  await writeFile(join(output,'result.json'),JSON.stringify({...evidence('PASS'),
    revision:execFileSync('git',['rev-parse','HEAD'],{encoding:'utf8'}).trim(),
    dirty:execFileSync('git',['status','--porcelain'],{encoding:'utf8'}).trim().split('\n'),
    note:'Local HTTP and browser evidence. Native Claude/Sites connections and GitHub live PR verdict are not verified.'},null,2)+'\n');
  console.log(JSON.stringify({status:'PASS',checks,output}));
} catch(error) {
  errors.push(error.message);await writeFile(join(output,'result.json'),JSON.stringify(evidence('FAIL'),null,2)+'\n');throw error;
} finally {if(browser)await browser.close();if(host)await host.close();await rm(directory,{recursive:true,force:true});}
