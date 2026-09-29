import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import test from 'node:test';

// Test-first boundary: no production stub is installed. Until the module
// exists, expose the explicitly unprotected baseline to the SAME assertions.
// This exercises the oracle; it is not evidence of existing product behavior.
const moduleUrl = new URL('../../plugins/sdd-context/privacy.mjs', import.meta.url);
const baseline = !existsSync(moduleUrl);
const redact = baseline
  ? (text) => ({ text, omission: false, ruleVersion: 1 })
  : (await import(moduleUrl.href)).redact;
console.log(`privacy subject: ${baseline ? 'test-only unprotected baseline' : 'production module'}`);
assert.equal(typeof redact, 'function', 'privacy module must export redact(text)');

// Synthetic values and scanner-sensitive keys are assembled at runtime.
const key = ['pass', 'word'].join('');
const secret = ['synthetic', 'only', 'value'].join('-');
const marker = (family) => `[${['RE', 'DACTED'].join('')}:${family}]`;

test('TEST-045b: assignment value removed, surrounding text preserved, omission disclosed', () => {
  const result = redact(`前 ${key}="${secret}" 後`);
  assert.equal(result.text.includes(secret), false, 'identified assignment value survived');
  assert.equal(result.text, `前 ${key}=${marker('assignment')} 後`);
  assert.equal(result.omission, true);
  assert.equal(result.ruleVersion, 1);
  assert.deepEqual(Object.keys(result).sort(), ['omission', 'ruleVersion', 'text']);
});

test('TEST-045c: authorization header removes the complete spaced value through CRLF', () => {
  const header = ['Author', 'ization'].join('');
  const scheme = ['Bear', 'er'].join('');
  const result = redact(`${header}: ${scheme} ${secret} extra\r\nnext line`);
  assert.equal(result.text.includes(secret), false, 'identified header value survived');
  assert.equal(result.text.includes('extra'), false, 'spaced header suffix survived');
  assert.equal(result.text, `${header}: ${marker('header')}\r\nnext line`);
  assert.equal(result.omission, true);
});

test('TEST-046a: unclosed identified quote rejects rather than returning writable text', () => {
  let rejected = false;
  try {
    redact(`${key}="${secret}`);
  } catch (error) {
    rejected = true;
    assert.equal(typeof error.code, 'string', 'rejection must have a content-free code');
    assert.match(error.code, /^[a-z][a-z-]*$/);
    assert.equal(String(error.message).includes(secret), false);
    assert.equal(JSON.stringify(error).includes(secret), false);
  }
  assert.equal(rejected, true, 'unclosed identified quote returned a writable payload');
});

test('TEST-045f control: ordinary Unicode and a non-key substring are unchanged', () => {
  const input = `普通の会話🙂 prefix_${key}_suffix=public`;
  assert.deepEqual(redact(input), { text: input, omission: false, ruleVersion: 1 });
});
