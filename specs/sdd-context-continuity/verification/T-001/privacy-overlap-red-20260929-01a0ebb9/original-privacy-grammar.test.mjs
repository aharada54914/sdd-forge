import assert from 'node:assert/strict';
import { existsSync } from 'node:fs';
import { performance } from 'node:perf_hooks';
import test from 'node:test';

const url = new URL('../../plugins/sdd-context/privacy.mjs', import.meta.url);
const baseline = !existsSync(url);
const redact = baseline ? (text) => ({ text, omission: false, ruleVersion: 1 }) : (await import(url.href)).redact;
console.log(`grammar subject: ${baseline ? 'test-only unprotected baseline' : 'production module'}`);
const keys = [['pass', 'word'], ['pass', 'wd'], ['sec', 'ret'], ['api', '_key'], ['api', 'key'], ['access', '_token'], ['refresh', '_token'], ['client', '_secret'], ['author', 'ization']].map(parts => parts.join(''));
const value = ['synthetic', 'credential'].join('-');
const mark = (family) => `[${['RE', 'DACTED'].join('')}:${family}]`;
const run = (text) => redact(text, performance.now() + 1000);
function removed(text, family) {
  const result = run(text);
  assert.equal(result.omission, true, 'omission disclosure missing');
  assert.equal(result.ruleVersion, 1);
  assert.equal(result.text.includes(value), false, 'synthetic value survived');
  assert.equal(result.text.includes(mark(family)), true, 'family marker missing');
  assert.deepEqual(Object.keys(result).sort(), ['omission', 'ruleVersion', 'text']);
  return result.text;
}
function rejected(text, deadline = performance.now() + 1000) {
  let caught;
  try { redact(text, deadline); } catch (error) { caught = error; }
  assert.ok(caught, 'unsafe input returned a writable payload');
  assert.deepEqual(Object.keys(caught), ['code']);
  assert.equal(caught.message.includes(value), false);
  assert.equal(caught.stack, undefined, 'raw stack retained');
  assert.equal(JSON.stringify(caught).includes(value), false);
}
const labels = ['PRIVATE KEY', 'RSA PRIVATE KEY', 'EC PRIVATE KEY', 'OPENSSH PRIVATE KEY'];
const pem = (label, body) => `-----${'BE' + 'GIN'} ${label}-----\n${body}\n-----${'E' + 'ND'} ${label}-----`;

test('TEST-045a / TEST-046b: four PEM labels, multiline and 4096/+1 bytes', () => {
  for (const label of labels) {
    assert.equal(removed(pem(label, value + '\r\nline'), 'pem'), mark('pem'));
    const size = 4096 - Buffer.byteLength(pem(label, ''));
    removed(pem(label, 'x'.repeat(size)), 'pem');
    rejected(pem(label, 'x'.repeat(size + 1)));
    rejected(pem(label, value).replace('END', 'OTHER'));
  }
});

test('TEST-045b: all keys, cases, quote styles and delimiters', () => {
  for (const key of keys) for (const spelling of [key, key.toUpperCase()]) {
    for (const quote of ['', "'", '"']) for (const delimiter of [':', '=']) {
      for (const valueQuote of ['', "'", '"']) {
        removed(`前 {${quote}${spelling}${quote}\t${delimiter} ${valueQuote}${value}${valueQuote}} 後`, 'assignment');
      }
    }
  }
});

test('TEST-045b: escaped quotes/backslashes, CRLF, empty values and ASCII key boundaries', () => {
  for (const literal of [JSON.stringify(value + '"\\'), "'" + value + "\\'\\\\'"]) {
    removed(`${keys[0]}=${literal}\r\nnext`, 'assignment');
  }
  assert.equal(run(`${keys[0]}=\r\nnext`).omission, false);
  assert.equal(run(`${keys[0]}=""`).omission, false);
  assert.equal(run(`${keys[0]}=''`).omission, false);
  for (const key of ['prefix_' + keys[0], keys[0] + '_suffix', '1' + keys[0]]) {
    const input = `${key}=${value}`;
    assert.equal(run(input).text, input);
  }
});

test('TEST-045c: Bearer/Basic headers preserve lines and suppress assignment termination', () => {
  for (const scheme of [['Bear', 'er'], ['Bas', 'ic']]) {
    assert.equal(removed(` \t${keys[8].toUpperCase()}: ${scheme.join('')} ${value} extra\r\nnext`, 'header'), ` \t${keys[8].toUpperCase()}: ${mark('header')}\r\nnext`);
  }
});

test('TEST-045d: both URL schemes, userinfo and all one-pass decoded query keys', () => {
  for (const scheme of ['http', 'https']) {
    removed(`${scheme}://user:${value}@example.invalid/path`, 'url');
    for (const key of keys) for (const encoded of [key, key.toUpperCase(), '%' + key.charCodeAt(0).toString(16) + key.slice(1)]) {
      assert.equal(removed(`${scheme}://example.invalid/?${encoded}=${value}#tail`, 'url'), mark('url'));
    }
  }
  const gap = `https://example.invalid/?pass+word=${value}`;
  assert.equal(run(gap).text, gap, 'plus decodes to space, not an exact key');
  assert.equal(removed(`<https://example.invalid/?%70assword=${value}>`, 'url'), `<${mark('url')}>`);
  // Raw query assignment overlaps the URL: '>' is not a bare-value terminator.
  assert.equal(removed(`<https://example.invalid/?${keys[0]}=${value}>`, 'url'), `<${mark('url')}`);
});

test('TEST-045e / TEST-046b: prefix bounds, AWS exact length and boundaries', () => {
  for (const prefix of [['s', 'k-'], ['gh', 'p_'], ['github', '_pat_']].map(p => p.join(''))) {
    for (const n of [20, 256]) removed(`🙂${prefix}${'x'.repeat(n)}🙂`, 'token');
    rejected(`${prefix}${'x'.repeat(257)}`);
    for (const input of [prefix + 'x'.repeat(19), 'a' + prefix + 'x'.repeat(20), prefix.toUpperCase() + 'x'.repeat(20)]) assert.equal(run(input).text, input);
  }
  for (const prefix of [['AK', 'IA'], ['AS', 'IA']].map(p => p.join(''))) {
    removed(`_${prefix}${'A'.repeat(16)}_`, 'token');
    rejected(prefix + 'A'.repeat(17));
    for (const input of [prefix + 'A'.repeat(15), 'Z' + prefix + 'A'.repeat(16), prefix + 'a'.repeat(16)]) assert.equal(run(input).text, input);
  }
});

test('TEST-045e / TEST-046b: linear JWT segments and aggregate sensitive-value bound', () => {
  for (const sizes of [[8, 8, 8], [2048, 8, 8], [2048, 2038, 8]]) removed(sizes.map(n => 'a'.repeat(n)).join('.'), 'jwt');
  for (const sizes of [[2049, 8, 8], [2048, 2039, 8]]) rejected(sizes.map(n => 'a'.repeat(n)).join('.'));
  for (const input of ['aaaaaaa.bbbbbbbb.cccccccc', 'aaaaaaaa.bbbbbbbb.cccccccc.dddddddd']) assert.equal(run(input).text, input);
});

test('TEST-045e: overlapping assignment/token spans merge and preserve Unicode', () => {
  const token = ['s', 'k-'].join('') + 'x'.repeat(20);
  assert.equal(removed(`🙂${keys[0]}="${token}"終`, 'assignment'), `🙂${keys[0]}=${mark('assignment')}終`);
});

test('TEST-045f: documented gaps do not become comprehensive detection claims', () => {
  for (const input of [`ftp://user:${value}@example.invalid`, `https://example.invalid/?%2570assword=${value}`, 'unnamed-person@example.invalid']) assert.equal(run(input).text, input);
});

test('TEST-046a: malformed identified values, isolated/decoded surrogates, wrong text type', () => {
  for (const suffix of ['"' + value, "'" + value, '"\\q"', "'\\n'", '|', '>', '"\\ud800"']) rejected(`${keys[0]}=${suffix}`);
  for (const input of ['\ud800', '\udc00', null, {}, 12]) rejected(input);
});

test('TEST-046b: malformed sensitive URLs and percent escapes', () => {
  for (const input of [`https://[bad/?${keys[0]}=${value}`, `https://example.invalid/?${keys[0]}=%zz`, `https://user:%zz@example.invalid`, `https://[bad/@${value}`]) rejected(input);
});

test('TEST-046b: 4096-byte bare/quoted/header/URL values and +1', () => {
  const key = keys[0];
  for (const wrap of [s => `${key}=${s}`, s => `${key}="${s}"`, s => `${key}='${s}'`, s => `${keys[8]}: ${s}`]) {
    const quoted = wrap('x').includes("'") || wrap('x').includes('"');
    const n = 4096 - (quoted ? 2 : 0);
    assert.equal(run(wrap('x'.repeat(n))).omission, true);
    rejected(wrap('x'.repeat(n + 1)));
  }
  const start = `https://u:${value}@example.invalid/`;
  removed(start + 'x'.repeat(4096 - start.length), 'url');
  rejected(start + 'x'.repeat(4097 - start.length));
  removed(`${key}=${'界'.repeat(1365)}x`, 'assignment');
  rejected(`${key}=${'界'.repeat(1365)}xx`);
});

test('TEST-046b: 1 MiB input, oversize and replacement expansion', () => {
  assert.equal(run(' '.repeat(1024 * 1024)).text.length, 1024 * 1024);
  rejected(' '.repeat(1024 * 1024 + 1));
  const tail = `${keys[0]}=x`;
  rejected(' '.repeat(1024 * 1024 - tail.length) + tail);
});

test('TEST-046c: 512 spans, 513 spans and elapsed process deadline', () => {
  assert.equal(run((keys[0] + '=x ').repeat(512)).omission, true);
  rejected((keys[0] + '=x ').repeat(513));
  rejected('ordinary', 0);
});

test('TEST-046c: scanner decoder exception exposes no raw cause/stack/payload', () => {
  const original = JSON.parse;
  try {
    JSON.parse = () => { throw new Error(value); };
    rejected(`${keys[0]}="${value}"`);
  } finally { JSON.parse = original; }
});

test('PRIVACY-IDEMPOTENCE-TEXT: generated output preserves exact text for six families', () => {
  const cases = [
    ['pem', pem(labels[0], value)],
    ...['', "'", '"'].map(quote => ['assignment', `🙂${keys[0]}=${quote}${value}${quote}\r\n終`]),
    ['header', ` \t${keys[8]}: ${['Bear', 'er'].join('')} ${value}\r\n終`],
    ['url', `https://user:${value}@example.invalid/`],
    ['token', ['s', 'k-'].join('') + value],
    ['jwt', ['a'.repeat(8), value, 'b'.repeat(8)].join('.')],
  ];
  const mismatches = [];
  for (const [index, [family, input]] of cases.entries()) {
    const first = removed(input, family);
    const second = run(first);
    assert.equal(second.text.includes(value), false, 'synthetic value returned');
    if (second.text !== first) mismatches.push({ index, family, first, second: second.text });
  }
  assert.deepEqual(mismatches, [], 'generated text changed on second scan');
});

test('PRIVACY-IDEMPOTENCE-PREFIX: complete, near and unfinished markers cannot hide a value', () => {
  for (const candidate of [
    mark('assignment').slice(0, -1) + value,
    mark('assignment').replace('assignment', 'Assignment' + value),
    mark('assignment').replace('assignment', 'assignment-' + value),
    mark('assignment') + value,
  ]) removed(`${keys[0]}=${candidate}`, 'assignment');
});
