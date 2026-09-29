import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { test } from 'node:test';
import { SourceTextModule, SyntheticModule, createContext } from 'node:vm';

// Synthetic Windows dependencies exercise dispatch, not native filesystem proof.
async function load(file, bindings, process = { platform: 'win32' }) {
  const context = createContext({ process, Error, Number, Math, URL });
  const module = new SourceTextModule(readFileSync(file, 'utf8'), { context,
    initializeImportMeta(meta) { meta.url = file.href; } });
  await module.link(specifier => {
    const values = bindings[specifier]; assert.ok(values, `unexpected dependency ${specifier}`);
    return new SyntheticModule(Object.keys(values), function () {
      for (const [key, value] of Object.entries(values)) this.setExport(key, value);
    }, { context });
  });
  await module.evaluate(); return module.namespace;
}
const subject = new URL('../../plugins/sdd-context/store-preparation.mjs', import.meta.url);
const adapter = new URL('../../plugins/sdd-context/windows-store.mjs', import.meta.url);
const trusted = { type: 'OwnerV1', owner: { worktreeRoot: '/owned' }, deadline: 100 };
const reject = action => assert.throws(action, error => error.message === 'validation-rejected' &&
  error.code === 'validation-rejected' && error.stack === undefined && error.cause === undefined);

test('WINDOWS-DISPATCH: shared validation brackets fixed-leaf native creation', async () => {
  const calls = []; const value = { schemaVersion: 1 };
  const module = await load(subject, {
    'node:fs': { closeSync() {}, constants: {}, fstatSync() {}, lstatSync() {}, mkdirSync() {
      assert.fail('Windows used POSIX mkdir'); }, openSync() {}, realpathSync: path => path },
    'node:path': { join: (...parts) => parts.join('/') },
    'node:perf_hooks': { performance: { now: () => 10 } },
    './validation.mjs': { validate: () => { calls.push('validate'); return value; } },
    './windows-store.mjs': { prepareWindowsStore: (...args) => calls.push(args) }
  });
  assert.equal(module.prepareStore('{}', trusted), value);
  assert.deepEqual(calls, ['validate', ['/owned/.sdd/context', 90], 'validate']);
});

test('WINDOWS-ADAPTER: bounded fixed script invocation; failures never leak', async () => {
  assert.ok(existsSync(adapter), 'Windows adapter is absent');
  const calls = []; let failure = false;
  const module = await load(adapter, {
    'node:child_process': { execFileSync: (...args) => {
      calls.push(args); if (failure) throw new Error('synthetic private path'); return 'created'; } },
    'node:url': { fileURLToPath: url => url.pathname }
  });
  module.prepareWindowsStore('/owned/.sdd/context', 90);
  assert.equal(calls[0][0], 'pwsh');
  assert.ok(calls[0][1].includes('/owned/.sdd/context'));
  assert.ok(calls[0][1].some(arg => arg.endsWith('/windows-store.ps1')));
  assert.equal(calls[0][2].timeout, 90);
  failure = true; reject(() => module.prepareWindowsStore('/owned/.sdd/context', 90));
  const before = calls.length;
  reject(() => module.prepareWindowsStore('/owned/.sdd/context', 0));
  assert.equal(calls.length, before);
});
