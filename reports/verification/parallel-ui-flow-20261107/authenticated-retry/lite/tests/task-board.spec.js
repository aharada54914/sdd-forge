'use strict';
const { chromium } = require('playwright');
const assert = require('node:assert/strict');
const { spawn } = require('node:child_process');
const fs = require('node:fs');

async function main() {
  const port = 4187;
  const url = `http://127.0.0.1:${port}`;
  const out = process.env.BOARD_EVIDENCE_DIR || 'evidence/T-001/browser';
  fs.mkdirSync(out, { recursive: true });
  const server = spawn('python3', ['-m', 'http.server', String(port), '--bind', '127.0.0.1'], { stdio: ['ignore', 'ignore', 'pipe'] });
  let serverError = '';
  server.stderr.on('data', data => { serverError += data.toString(); });
  let browser;
  const results = [];
  try {
    let ready = false;
    for (let attempt = 0; attempt < 40; attempt++) {
      try { await fetch(url); ready = true; break; } catch { await new Promise(resolve => setTimeout(resolve, 100)); }
      if (server.exitCode !== null) break;
    }
    assert.equal(ready, true, `Local test server did not start: ${serverError}`);
    browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium', headless: true, args: ['--no-sandbox'] });
    const context = await browser.newContext();
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', err => errors.push(err.message));
    const add = async title => {
      await page.getByLabel('New task').fill(title);
      await page.getByRole('button', { name: 'Add task', exact: true }).click();
    };
    const title = page.getByLabel('New task');
    await page.goto(url);
    assert.equal(await page.locator('#empty').isVisible(), true);
    await add('   ');
    assert.equal(await page.getByRole('alert').textContent(), 'Enter a task title.');
    assert.equal(await page.locator('li').count(), 0);
    await add('  Read a book  ');
    assert.equal(await title.inputValue(), '');
    assert.equal(await title.evaluate(el => document.activeElement === el), true);
    assert.equal(await page.getByRole('checkbox', { name: 'Read a book', exact: true }).count(), 1);
    await title.fill('Take a walk');
    await title.press('Enter');
    await page.reload();
    assert.deepEqual(await page.locator('li label').allTextContents(), ['Read a book', 'Take a walk']);
    const check = page.getByRole('checkbox', { name: 'Read a book', exact: true });
    await check.check();
    await page.reload();
    assert.equal(await check.isChecked(), true);
    assert.equal(await check.locator('..').getAttribute('class'), 'completed');
    await check.focus();
    await check.press('Space');
    await page.reload();
    assert.equal(await check.isChecked(), false);
    await page.getByRole('button', { name: 'Delete Read a book', exact: true }).click();
    await page.reload();
    assert.deepEqual(await page.locator('li label').allTextContents(), ['Take a walk']);
    results.push('PASS: empty, whitespace validation, trimmed button/Enter add, input focus, ordered reload persistence, complete/reopen keyboard and reload, targeted delete and reload');

    await add('<img src=x onerror="window.injected=true">');
    assert.equal(await page.locator('li img').count(), 0);
    assert.equal(await page.evaluate(() => window.injected), undefined);
    const newContext = await browser.newContext();
    const fresh = await newContext.newPage();
    await fresh.goto(url);
    assert.equal(await fresh.locator('li').count(), 0);
    await newContext.close();
    results.push('PASS: literal HTML-like titles; fresh storage context starts empty');

    await page.setViewportSize({ width: 360, height: 780 });
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
    await title.focus();
    const outline = await title.evaluate(el => getComputedStyle(el).outlineStyle);
    assert.notEqual(outline, 'none');
    await page.screenshot({ path: `${out}/mobile.png`, fullPage: true });
    await page.setViewportSize({ width: 1100, height: 850 });
    await page.screenshot({ path: `${out}/desktop.png`, fullPage: true });
    results.push('PASS: narrow viewport without horizontal overflow; visible keyboard focus; screenshots saved');

    for (const value of ['{broken', JSON.stringify([{ id: 'x', title: '', completed: false }])]) {
      await page.evaluate(value => localStorage.setItem('task-board.tasks.v1', value), value);
      await page.reload();
      assert.equal(await page.locator('#storage-warning').isVisible(), true);
      assert.equal(await page.locator('li').count(), 0);
      await add('Recovered list');
      assert.equal(await page.locator('li').count(), 1);
    }
    results.push('PASS: malformed JSON and invalid schema warn and allow task creation');

    const failedContext = await browser.newContext();
    await failedContext.addInitScript(() => {
      Storage.prototype.getItem = () => { throw new Error('Read unavailable'); };
      Storage.prototype.setItem = () => { throw new Error('Write unavailable'); };
    });
    const failed = await failedContext.newPage();
    await failed.goto(url);
    assert.equal(await failed.locator('#storage-warning').isVisible(), true);
    await failed.getByLabel('New task').fill('Session only');
    await failed.getByLabel('New task').press('Enter');
    await failed.getByRole('checkbox', { name: 'Session only', exact: true }).check();
    assert.equal(await failed.getByRole('checkbox').isChecked(), true);
    assert.match(await failed.locator('#storage-warning').textContent(), /cannot be saved/);
    await failed.getByRole('button', { name: 'Delete Session only', exact: true }).click();
    assert.equal(await failed.locator('li').count(), 0);
    await failedContext.close();
    results.push('PASS: unavailable storage warns; in-session add, toggle and delete work');
    assert.deepEqual(errors, []);
    results.push('PASS: no page JavaScript errors');
    console.log(results.join('\n'));
    fs.writeFileSync(`${out}/results.json`, JSON.stringify({ status: 'PASS', results }, null, 2));
  } catch (error) {
    fs.writeFileSync(`${out}/results.json`, JSON.stringify({ status: 'FAIL', results, error: error.stack }, null, 2));
    throw error;
  } finally {
    if (browser) await browser.close();
    server.kill();
  }
}
main().catch(error => { console.error(error); process.exitCode = 1; });
