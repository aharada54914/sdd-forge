import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { performance } from 'node:perf_hooks';
import test from 'node:test';

const moduleUrl = new URL('../../plugins/sdd-context/json-admission.mjs', import.meta.url);
const absent = !existsSync(moduleUrl);
const parseJson = absent ? undefined : (await import(moduleUrl.href)).parseJson;
console.log(`JSON admission subject: ${absent ? 'shared API absent; no substitute' : 'production module'}`);
test('TEST-046a JSON-API: planned shared admission API must exist', () => {
  assert.equal(typeof parseJson, 'function', 'shared parseJson API is not implemented');
});
// Every case requires the real API; missing implementation is RED, never skipped.
const check = (name, body) => test(name, () => {
  assert.equal(typeof parseJson, 'function', 'shared parseJson API is not implemented');
  body();
});
const admit = source => parseJson(source, performance.now() + 1000);

function rejected(source, deadline = performance.now() + 1000) {
  const forwarded = [];
  let caught;
  try { forwarded.push(parseJson(source, deadline)); } catch (error) { caught = error; }
  assert.equal(forwarded.length, 0, 'invalid JSON reached the synthetic admission sink');
  assert.ok(caught instanceof Error, 'rejection did not produce an internal error');
  assert.deepEqual(Object.keys(caught), ['code']);
  assert.match(caught.code, /^[a-z][a-z-]*$/);
  assert.equal(caught.message, caught.code, 'rejection retained free-form content');
  assert.equal(caught.stack, undefined, 'rejection retained a stack');
  assert.equal(caught.cause, undefined, 'rejection retained its cause');
}

check('TEST-046a JSON-DUPLICATE: repeated decoded names reject even with identical values', () => {
  for (const source of ['{"x":1,"x":2}', '{"x":1,"x":1}']) rejected(source);
});

check('TEST-046a JSON-DUPLICATE: escape-equivalent names reject after decoding', () => {
  for (const source of [
    String.raw`{"a":0,"\u0061":1}`,
    String.raw`{"a/b":0,"a\/b":1}`,
    String.raw`{"a\"b":0,"a\u0022b":1}`,
    String.raw`{"\\":0,"\u005c":1}`,
    String.raw`{"🙂":0,"\ud83d\ude42":1}`,
  ]) rejected(source);
});

check('TEST-046a JSON-DUPLICATE: nested objects and array elements use their own member sets', () => {
  for (const source of [
    '{"outer":{"x":1,"x":2}}',
    '[{"ok":1},{"x":1,"x":2}]',
    String.raw`{"outer":[{"x":1,"\u0078":2}]}`,
  ]) rejected(source);
});

check('TEST-046a JSON-DUPLICATE: prototype-like names are ordinary member identities', () => {
  for (const key of ['__proto__', 'constructor', 'toString']) {
    const name = JSON.stringify(key);
    rejected(`{${name}:1,${name}:2}`);
  }
});

check('TEST-046a JSON-UNICODE: decoded isolated/reversed surrogates in values and names reject', () => {
  for (const escaped of [String.raw`\ud800`, String.raw`\udc00`, String.raw`\udc00\ud800`, String.raw`\ud800x`, String.raw`x\udc00`]) {
    rejected(`"${escaped}"`);
    rejected(`{"${escaped}":0}`);
  }
});

check('TEST-046a JSON-UNICODE: raw isolated surrogates in source names and values reject', () => {
  for (const raw of ['\ud800', '\udc00', '\udc00\ud800']) {
    rejected(`"${raw}"`);
    rejected(`{"${raw}":0}`);
  }
});

check('TEST-046a JSON-UNICODE: nested decoded keys and values reject', () => {
  for (const source of [
    String.raw`{"outer":["\ud800"]}`,
    String.raw`[{"outer":{"\udc00":0}}]`,
  ]) rejected(source);
});

check('TEST-046a JSON-SYNTAX: malformed JSON/escape errors remain content-free', () => {
  for (const source of ['{"x":', '{"x":1,}', '{"x":1} trailing', '"unterminated', String.raw`"\q"`, '"raw\nline"', '/*comment*/{}']) rejected(source);
});

check('TEST-046a controls: valid JSON/Unicode preserve standard decoder values and separate scopes', () => {
  const sources = [
    'null', 'true', '12.5', '[]', '{}',
    '{"x":1,"X":2,"é":3,"e\\u0301":4}',
    '{"x":1,"child":{"x":2},"items":[{"x":3},{"x":4}]}',
    '{"__proto__":1,"constructor":2,"toString":3}',
    String.raw`{"🙂":"\ud83d\ude42","escaped":"\\ud800"}`,
    JSON.stringify({ text: '{"x":1,"x":2}', punctuation: '],:{"\\', unicode: '会話🙂\r\n' }),
  ];
  for (const source of sources) assert.deepEqual(admit(source), JSON.parse(source));
});

check('TEST-046a JSON-BOUNDS: exact 1 MiB UTF-8 input fits, +1 rejects without truncation', () => {
  const source = JSON.stringify('界');
  const exact = source + ' '.repeat(1024 * 1024 - Buffer.byteLength(source));
  assert.equal(Buffer.byteLength(exact), 1024 * 1024);
  assert.equal(admit(exact), '界');
  rejected(exact + ' ');
});

check('TEST-046a JSON-BOUNDS: wrong source type and exhausted/nonfinite trusted deadline reject', () => {
  for (const source of [null, {}, 12]) rejected(source);
  for (const deadline of [0, NaN, Infinity]) rejected('{}', deadline);
});
