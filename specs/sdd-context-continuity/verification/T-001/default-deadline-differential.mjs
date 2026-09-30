import assert from 'node:assert/strict';
import { mock } from 'node:test';
import { performance } from 'node:perf_hooks';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

assert.ok(process.argv[2], 'Pass a checkout containing the published 1000ms defaults.');
for (const [label, root] of [['published', process.argv[2]], ['current', process.cwd()]]) {
  for (const [file, api, input, expected, code] of [
    ['json-admission.mjs', 'parseJson', '{"x":1}', { x: 1 }, 'json-rejected'],
    ['privacy.mjs', 'redact', 'ordinary text', { text: 'ordinary text', omission: false, ruleVersion: 1 }, 'privacy-rejected'],
  ]) {
    const fn = (await import(pathToFileURL(resolve(root, 'plugins/sdd-context', file)).href))[api];
    const clock = mock.method(performance, 'now', () => 1500);
    try {
      if (label === 'published') assert.throws(() => fn(input), { code });
      else assert.deepEqual(fn(input), expected);
      clock.mock.mockImplementation(() => 3000);
      assert.throws(() => fn(input), error => {
        assert.deepEqual(Object.keys(error), ['code']);
        assert.equal(error.code, code);
        assert.equal(error.message, code);
        assert.equal(error.stack, undefined);
        assert.equal(error.cause, undefined);
        return true;
      });
      clock.mock.mockImplementation(() => 1500);
      assert.throws(() => fn(input, 1000), { code });
      console.log(`${label} ${api}: default at 1500ms, closed boundary at 3000ms, explicit 1000ms checked`);
    } finally {
      clock.mock.restore();
    }
  }
}
console.log('12 deadline cases passed; mocked clock, not native process-lifecycle proof.');
