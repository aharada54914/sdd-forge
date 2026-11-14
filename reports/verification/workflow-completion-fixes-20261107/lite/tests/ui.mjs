import { chromium } from '/opt/codex/cua_node/lib/node_modules/playwright/index.mjs';
import assert from 'node:assert/strict';
import { writeFile, mkdir } from 'node:fs/promises';
const output = 'reports/visual-evidence/task-board';
await mkdir(output, {recursive:true});
const browser = await chromium.launch({headless:true, executablePath:'/usr/bin/chromium'});
const results = [];
const evidence = {};
const url = 'http://127.0.0.1:4173';
const key = 'task-board:v1';
async function ready(page) { await page.waitForFunction(() => document.documentElement.style.getPropertyValue('--color-primary')); }
async function add(page, title) { await page.getByRole('textbox').fill(title); await page.getByRole('textbox').press('Enter'); }
async function checked(page, name, expected) { assert.equal(await page.getByRole('checkbox', {name, exact:true}).isChecked(), expected); }
try {
for (const [view, viewport] of [['desktop',{width:1280,height:1000}],['mobile',{width:390,height:844}]]) {
 const context = await browser.newContext({viewport});
 const page = await context.newPage();
 const errors=[];page.on('pageerror', error=>errors.push(error.message));
 await page.goto(url);await ready(page);
 await page.screenshot({path:`${output}/${view}-empty.png`,fullPage:true});
 await page.getByRole('textbox').fill('   ');await page.getByRole('textbox').press('Enter');
 assert.match(await page.getByRole('alert').innerText(),/入力してください/);
 assert.equal(await page.getByRole('textbox').getAttribute('aria-invalid'),'true');
 const literal='<img src=x onerror="window.injected=true">';
 await add(page,literal);
 assert.equal(await page.locator('.task img').count(),0);
 assert.equal(await page.evaluate(()=>window.injected),undefined);
 assert.equal(await page.locator('#validation').textContent(),'');
 await page.reload();await ready(page);await checked(page,literal,false);
 const box=page.getByRole('checkbox',{name:literal,exact:true});
 await box.focus();await page.keyboard.press('Space');await checked(page,literal,true);
 assert.equal(await box.evaluate(el=>el===document.activeElement),true);
 await page.reload();await ready(page);await checked(page,literal,true);
 await page.getByRole('checkbox',{name:literal,exact:true}).uncheck();
 await page.reload();await ready(page);await checked(page,literal,false);
 await page.getByRole('button',{name:`${literal} を削除`,exact:true}).click();
 await page.reload();await ready(page);assert.equal(await page.getByRole('checkbox').count(),0);
 assert.deepEqual(await page.evaluate(k=>JSON.parse(localStorage.getItem(k)),key),[]);
 for(const title of ['会議の資料を準備する','買い物リストを確認する','明日の予定を整理する']) await add(page,title);
 await page.getByRole('checkbox',{name:'買い物リストを確認する',exact:true}).check();
 await page.getByRole('textbox').focus();
 assert.equal(await page.getByRole('textbox').evaluate(el=>getComputedStyle(el).outlineStyle),'solid');
 await page.screenshot({path:`${output}/${view}-populated.png`,fullPage:true});
 evidence[view]={viewport,aria:await page.locator('main').ariaSnapshot(),styles:await page.locator('body').evaluate(el=>({color:getComputedStyle(el).color,background:getComputedStyle(el).backgroundColor,font:getComputedStyle(el).fontFamily})),primary:await page.locator('.entry button').evaluate(el=>getComputedStyle(el).backgroundColor)};
 await add(page,'長いタスク'.repeat(50));
 assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);
 assert.deepEqual(errors,[]);
 results.push(`${view}: empty validation, literal titles, Enter add, keyboard toggle/focus, complete/reopen/delete reload persistence, long title overflow, no runtime errors PASS`);
 await context.close();
}
for(const [name, raw] of [['malformed-json','{bad'],['wrong-schema','[{"id":"x","title":" ","completed":false}]'],['duplicate-ids','[{"id":"x","title":"a","completed":false},{"id":"x","title":"b","completed":true}]']]) {
 const context=await browser.newContext();const page=await context.newPage();await page.goto(url);await ready(page);
 await page.evaluate(([k,value])=>localStorage.setItem(k,value),[key,raw]);await page.reload();await ready(page);
 assert.match(await page.getByRole('status').innerText(),/利用できません/);
 assert.equal(await page.evaluate(k=>localStorage.getItem(k),key),raw);
 await add(page,'復旧後のタスク');await checked(page,'復旧後のタスク',false);
 await page.getByRole('checkbox').check();await checked(page,'復旧後のタスク',true);
 await page.getByRole('button',{name:'復旧後のタスク を削除',exact:true}).click();assert.equal(await page.getByRole('checkbox').count(),0);
 results.push(`${name}: warning, original data unchanged on initial load, session add/toggle/delete PASS`);await context.close();
}
for(const mode of ['read','write','both']) {
 const context=await browser.newContext({viewport:{width:390,height:844}});
 await context.addInitScript(mode=>{
  if(mode==='read'||mode==='both') Storage.prototype.getItem=function(){throw new DOMException('Blocked','SecurityError');};
  if(mode==='write'||mode==='both') Storage.prototype.setItem=function(){throw new DOMException('Full','QuotaExceededError');};
 },mode);
 const page=await context.newPage();await page.goto(url);await ready(page);
 await add(page,'保存できなくても使える');await checked(page,'保存できなくても使える',false);
 await page.getByRole('checkbox').check();await checked(page,'保存できなくても使える',true);
 assert.match(await page.getByRole('status').innerText(),/利用できません/);
 await page.screenshot({path:`${output}/mobile-storage-${mode}-error.png`,fullPage:true});
 await page.getByRole('checkbox').uncheck();await checked(page,'保存できなくても使える',false);
 await page.getByRole('button',{name:'保存できなくても使える を削除',exact:true}).click();assert.equal(await page.getByRole('checkbox').count(),0);
 results.push(`storage ${mode} throws: visible warning and session add/complete/reopen/delete PASS`);await context.close();
}
await writeFile(`${output}/browser-evidence.json`,JSON.stringify({browser:await browser.version(),url,results,evidence},null,2));
console.log(results.join('\n'));
} finally { await browser.close(); }
