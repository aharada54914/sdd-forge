import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, realpathSync, rmSync, statSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { delimiter, join, relative, sep } from 'node:path';
import { performance } from 'node:perf_hooks';
import test, { after } from 'node:test';

// Fixed contract for the single T-001 entrance; no admission substitute.
// validate(rawJSON, trustedContext) returns the validated/redacted object only.
// trustedContext is core-owned, never copied from request fields.
const subject = new URL('../../plugins/sdd-context/validation.mjs', import.meta.url);
const validate = existsSync(subject) ? (await import(subject.href)).validate : undefined;
const preparationSubject = new URL('../../plugins/sdd-context/store-preparation.mjs', import.meta.url);
const prepareStore = existsSync(preparationSubject) ? (await import(preparationSubject.href)).prepareStore : undefined;
const { redact: journalRedact } = await import(new URL('../../plugins/sdd-context/privacy.mjs', import.meta.url).href);
const scratch = realpathSync(mkdtempSync(join(tmpdir(), 'sdd-context-validation-')));
after(() => rmSync(scratch, { recursive: true, force: true }));
function git(root, ...args) {
  const env = { ...process.env };
  // Keep fixture commits/index/object storage isolated from repository-selection env.
  for (const key of Object.keys(env)) if (key.startsWith('GIT_')) delete env[key];
  Object.assign(env, { GIT_AUTHOR_NAME: 'SDD fixture', GIT_AUTHOR_EMAIL: 'fixture@example.invalid',
    GIT_COMMITTER_NAME: 'SDD fixture', GIT_COMMITTER_EMAIL: 'fixture@example.invalid' });
  const result = spawnSync('git', ['-C', root, ...args], { encoding: 'utf8', env });
  assert.equal(result.error, undefined, 'fixture Git executor unavailable');
  assert.equal(result.status, 0, `fixture Git setup failed: ${result.stderr}`);
  return result.stdout;
}
function fixture(name, ignored = true, objectFormat = 'sha1') {
  const root = join(scratch, name);
  mkdirSync(root);
  git(root, 'init', '--quiet', `--object-format=${objectFormat}`);
  mkdirSync(join(root, 'specs', 'fixture-feature'), { recursive: true });
  mkdirSync(join(root, '.sdd', 'context'), { recursive: true });
  writeFileSync(join(root, '.gitignore'), ignored ? '.sdd/context/**\n' : '');
  const owner = { schemaVersion: 1, sddRoot: root, worktreeRoot: root,
    gitDirectory: realpathSync(join(root, '.git')), featureId: 'fixture-feature',
    host: 'codex', sessionId: 'fixture-session' };
  return { root, owner, target: join(root, '.sdd', 'context', 'prepared.json') };
}
function commitFixture(f) {
  git(f.root, '-c', 'commit.gpgsign=false', 'commit', '--quiet', '--allow-empty', '-m', 'synthetic fixture');
  return git(f.root, 'rev-parse', '--verify', 'HEAD').trim();
}
const normal = fixture('normal', true, 'sha256');
const normalHead = commitFixture(normal);
const sha1 = fixture('sha1');
const sha1Head = commitFixture(sha1);
const unsupportedGit = fixture('unsupported-format', true, 'sha256');
const unsupportedHead = commitFixture(unsupportedGit);
git(unsupportedGit.root, 'config', 'extensions.objectFormat', 'unsupported');
const missingIgnore = fixture('missing-ignore', false);
const negatedIgnore = fixture('negated-ignore');
writeFileSync(join(negatedIgnore.root, '.gitignore'), '.sdd/context/**\n!.sdd/context/prepared.json\n');
const tracked = fixture('tracked');
writeFileSync(tracked.target, 'fixture');
git(tracked.root, 'add', '--force', '.sdd/context/prepared.json');
const brokenGit = fixture('broken-git');
rmSync(join(brokenGit.root, '.git'), { recursive: true });
const outside = join(scratch, 'outside');
mkdirSync(outside);
symlinkSync(outside, join(normal.root, '.sdd', 'context', 'escape'));

const hash = 'a'.repeat(64);
const task = { id: 'T-001', approval: 'Approved', status: 'In Progress', blockersNonEmpty: false };
const cursor = () => ({ schemaVersion: 1, owner: { ...normal.owner }, segmentId: 'segment', sequence: 0, hash });
const projection = () => ({ schemaVersion: 1, owner: { ...normal.owner }, head: normalHead,
  authorityHashes: [{ path: 'specs/fixture-feature/tasks.md', sha256: hash }],
  taskLifecycle: [{ ...task }], featurePresent: true, journalCursor: null, decisions: [] });
const observation = owner => ({ schemaVersion: 1, owner: { ...owner }, kind: 'prompt', text: 'ordinary text', coverage: 'complete' });
function context(type, f = normal, extra = {}) {
  return { type, owner: { ...f.owner }, plannedPaths: [f.target], journalEmpty: true,
    deadline: performance.now() + 1000, ...extra };
}
const admit = (value, type = 'ProjectionV1', extra = {}) => validate(JSON.stringify(value), context(type, normal, extra));
function rejected(value, type = 'ProjectionV1', f = normal, extra = {}, raw = false) {
  const forwarded = [];
  let caught;
  try { forwarded.push(validate(raw ? value : JSON.stringify(value), context(type, f, extra))); }
  catch (error) { caught = error; }
  assert.equal(forwarded.length, 0, 'rejected input returned an in-memory writable result');
  assert.ok(caught instanceof Error, 'expected content-free rejection');
  assert.deepEqual(Object.keys(caught), ['code']);
  assert.match(caught.code, /^[a-z][a-z-]*$/);
  assert.equal(caught.message, caught.code);
  assert.equal(caught.stack, undefined);
  assert.equal(caught.cause, undefined);
}
function check(name, body) {
  test(name, () => {
    assert.equal(typeof validate, 'function', 'shared validate API is not implemented');
    body();
  });
}

test('fixture control: real Git ignore and tracked states are distinct', () => {
  assert.ok(git(normal.root, 'check-ignore', '--no-index', normal.target).trim());
  assert.equal(git(tracked.root, 'ls-files', '--', tracked.target).trim(), '.sdd/context/prepared.json');
});
test('fixture control: production Git path checks accept the ignored target', () => {
  const env = { ...process.env };
  for (const key of ['GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE', 'GIT_PREFIX']) delete env[key];
  const run = (...args) => spawnSync('git', ['-C', normal.root, ...args], { encoding: 'utf8', env });
  const top = run('rev-parse', '--show-toplevel');
  assert.equal(top.status, 0, 'Git top-level lookup');
  assert.equal(realpathSync.native(top.stdout.trim()), realpathSync.native(normal.root), 'Git top-level identity');
  const directory = run('rev-parse', '--absolute-git-dir');
  assert.equal(directory.status, 0, 'Git directory lookup');
  assert.equal(realpathSync.native(directory.stdout.trim()), realpathSync.native(normal.owner.gitDirectory), 'Git directory identity');
  const target = relative(normal.root, normal.target).split(sep).join('/');
  assert.equal(run('check-ignore', '--quiet', '--no-index', '--', target).status, 0, 'Git ignored target');
  const tracked = run('ls-files', '-z', '--', target);
  assert.equal(tracked.status, 0, 'Git tracked-target lookup');
  assert.equal(tracked.stdout.length, 0, 'Git target is untracked');
});
test('validation does not require a local rtk executable', () => {
  if (process.platform === 'win32') return;
  const bin = join(scratch, 'blocked-rtk');
  mkdirSync(bin);
  writeFileSync(join(bin, 'rtk'), '#!/bin/sh\nexit 78\n', { mode: 0o755 });
  const originalPath = process.env.PATH;
  process.env.PATH = `${bin}${delimiter}${originalPath}`;
  try { assert.deepEqual(admit(projection()), projection()); }
  finally { process.env.PATH = originalPath; }
});
check('VALIDATION-API: one real shared entrance exists', () => {});
check('PROJECTION-VALID: approved empty-journal shape returns the validated object', () => {
  assert.deepEqual(admit(projection()), projection());
});
check('ID-1024: ASCII and multibyte opaque IDs accept exactly 1024 UTF-8 bytes', () => {
  for (const id of ['x'.repeat(1024), '🙂'.repeat(256)]) {
    const value = projection(); value.journalCursor = { ...cursor(), segmentId: id };
    assert.equal(admit(value, 'ProjectionV1', { journalEmpty: false }).journalCursor.segmentId, id);
  }
});
check('ID-INVALID: empty, 1025-byte and malformed Unicode opaque IDs reject', () => {
  for (const id of ['', 'x'.repeat(1025), '🙂'.repeat(256) + 'x', '\ud800']) {
    const value = projection(); value.journalCursor = { ...cursor(), segmentId: id };
    rejected(value, 'ProjectionV1', normal, { journalEmpty: false });
  }
});
check('HASH-VALID: distinct authority paths may share a hash', () => {
  const value = projection(); value.authorityHashes.push({ path: 'specs/fixture-feature/design.md', sha256: hash });
  assert.deepEqual(admit(value).authorityHashes, value.authorityHashes);
});
check('HASH-CLOSED: every authority entry requires path/sha256 and forbids extra fields', () => {
  for (const entry of [{ sha256: hash }, { path: 'p' }, { path: 'p', sha256: hash, extra: true }, { path: 1, sha256: hash }]) {
    const value = projection(); value.authorityHashes = [entry]; rejected(value);
  }
});
check('HASH-DUPLICATE: duplicate authority paths reject even with identical hashes', () => {
  const value = projection(); value.authorityHashes.push({ ...value.authorityHashes[0] }); rejected(value);
});
check('HASH-FORMAT: authority digests reject uppercase, wrong size and non-hex', () => {
  for (const digest of ['A'.repeat(64), 'a'.repeat(63), 'a'.repeat(65), 'g'.repeat(64)]) {
    const value = projection(); value.authorityHashes[0].sha256 = digest; rejected(value);
  }
});
check('TASK-VALID: existing taskEntry optional fields and lifecycle enums accept', () => {
  for (const status of ['Planned', 'In Progress', 'Blocked', 'Implementation Complete', 'Done']) {
    const value = projection(); value.taskLifecycle = [{ ...task, status, approvalAnnotation: 'human',
      risk: 'high', requiredWorkflow: 'tdd', secondApproval: 'pending' }];
    assert.deepEqual(admit(value).taskLifecycle, value.taskLifecycle);
  }
});
check('TASK-CLOSED: required fields, field types and taskStateData-only extensions reject', () => {
  for (const field of Object.keys(task)) {
    const value = projection(); delete value.taskLifecycle[0][field]; rejected(value);
  }
  for (const change of [{ tasksFile: 'tasks.md' }, { failures: [] }, { extra: true }, { blockersNonEmpty: 'false' },
    { id: 'T-one' }, { approvalAnnotation: false }, { requiredWorkflow: [] }, { secondApproval: 1 }]) {
    const value = projection(); Object.assign(value.taskLifecycle[0], change); rejected(value);
  }
});
check('TASK-ENUM: invalid approval/status/risk values reject', () => {
  for (const change of [{ approval: 'approved' }, { status: 'done' }, { risk: 'High' }]) {
    const value = projection(); Object.assign(value.taskLifecycle[0], change); rejected(value);
  }
});
check('CURSOR-NULL: nonempty journal forbids a null cursor', () => {
  rejected(projection(), 'ProjectionV1', normal, { journalEmpty: false });
});
check('CURSOR-VALID: closed owned cursor accepts for a nonempty journal', () => {
  const value = projection(); value.journalCursor = cursor();
  assert.deepEqual(admit(value, 'ProjectionV1', { journalEmpty: false }).journalCursor, value.journalCursor);
});
check('CURSOR-CLOSED: each required field, safe sequence, hash and content extensions are checked', () => {
  for (const field of Object.keys(cursor())) {
    const value = projection(); value.journalCursor = cursor(); delete value.journalCursor[field];
    rejected(value, 'ProjectionV1', normal, { journalEmpty: false });
  }
  for (const change of [{ schemaVersion: 2 }, { sequence: -1 }, { sequence: 0.5 },
    { sequence: Number.MAX_SAFE_INTEGER + 1 }, { hash: 'bad' }, { text: 'foreign content' }]) {
    const value = projection(); value.journalCursor = { ...cursor(), ...change };
    rejected(value, 'ProjectionV1', normal, { journalEmpty: false });
  }
});
check('OWNER-MISMATCH: repository/worktree/Git directory/feature/host/session cannot self-authorize', () => {
  for (const field of ['sddRoot', 'worktreeRoot', 'gitDirectory', 'featureId', 'host', 'sessionId']) {
    const value = observation(normal.owner); value.owner[field] = field === 'host' ? 'claude' : 'foreign';
    rejected(value, 'ObservationV1');
  }
});
check('CURSOR-FOREIGN: foreign owner and unproven predecessor session reject', () => {
  for (const change of [{ owner: { ...normal.owner, sessionId: 'foreign' } }, { predecessorSessionId: 'unproven' }]) {
    const value = projection(); value.journalCursor = { ...cursor(), ...change };
    rejected(value, 'ProjectionV1', normal, { journalEmpty: false });
  }
});
check('SCHEMA-CLOSED: projection/owner version, required fields and unknown keys reject', () => {
  for (const field of Object.keys(projection())) { const value = projection(); delete value[field]; rejected(value); }
  for (const field of Object.keys(normal.owner)) { const value = projection(); delete value.owner[field]; rejected(value); }
  for (const change of [{ schemaVersion: 2 }, { featurePresent: 'true' }, { taskLifecycle: {} }, { decisions: {} }, { extra: true }]) {
    const value = { ...projection(), ...change }; rejected(value);
  }
  const value = projection(); value.owner.extra = true; rejected(value);
});
check('JSON-DUPLICATE: duplicate decoded fields reject through the same entrance', () => {
  const source = JSON.stringify(observation(normal.owner)).replace('"schemaVersion":1', '"schemaVersion":1,"schemaVersion":1');
  rejected(source, 'ObservationV1', normal, {}, true);
});
check('REQUEST-AUTHORITY: caller cannot supply receipt/sequence/expiry/path/budget/lifecycle', () => {
  for (const field of ['receivedAtUtc', 'sequence', 'expiry', 'plannedPaths', 'deadline', 'taskLifecycle']) {
    const value = observation(normal.owner); value[field] = 'caller'; rejected(value, 'ObservationV1');
  }
});
check('IGNORE-MISSING: non-ignored content target rejects', () => rejected(observation(missingIgnore.owner), 'ObservationV1', missingIgnore));
check('IGNORE-ENV: inherited Git config cannot invent an ignore rule', () => {
  const excludes = join(scratch, 'injected-excludes');
  writeFileSync(excludes, '.sdd/context/**\n');
  const keys = ['GIT_CONFIG_COUNT', 'GIT_CONFIG_KEY_0', 'GIT_CONFIG_VALUE_0'];
  const previous = keys.map(key => process.env[key]);
  Object.assign(process.env, {
    GIT_CONFIG_COUNT: '1', GIT_CONFIG_KEY_0: 'core.excludesFile', GIT_CONFIG_VALUE_0: excludes,
  });
  try { rejected(observation(missingIgnore.owner), 'ObservationV1', missingIgnore); }
  finally {
    keys.forEach((key, index) => {
      if (previous[index] === undefined) delete process.env[key];
      else process.env[key] = previous[index];
    });
  }
});
check('IGNORE-GLOBAL: inherited HOME and XDG config cannot invent an ignore rule', () => {
  const excludes = join(scratch, 'global-excludes');
  writeFileSync(excludes, '.sdd/context/**\n');
  const home = join(scratch, 'injected-home');
  const xdg = join(scratch, 'injected-xdg');
  mkdirSync(home);
  mkdirSync(join(xdg, 'git'), { recursive: true });
  const config = `[core]\n\texcludesFile = ${excludes.replaceAll('\\', '/')}\n`;
  writeFileSync(join(home, '.gitconfig'), config);
  writeFileSync(join(xdg, 'git', 'config'), config);
  const previous = [process.env.HOME, process.env.XDG_CONFIG_HOME];
  process.env.HOME = home;
  process.env.XDG_CONFIG_HOME = xdg;
  try {
    const target = relative(missingIgnore.root, missingIgnore.target).split(sep).join('/');
    const control = spawnSync('git', ['-C', missingIgnore.root, 'check-ignore', '--quiet', '--no-index', '--', target],
      { env: process.env });
    assert.equal(control.status, 0, 'fixture global ignore must affect ordinary Git');
    rejected(observation(missingIgnore.owner), 'ObservationV1', missingIgnore);
  }
  finally {
    for (const [index, key] of ['HOME', 'XDG_CONFIG_HOME'].entries()) {
      if (previous[index] === undefined) delete process.env[key];
      else process.env[key] = previous[index];
    }
  }
});
check('IGNORE-NEGATED: effective negation rejects', () => rejected(observation(negatedIgnore.owner), 'ObservationV1', negatedIgnore));
check('TRACKED: ignored but tracked content target rejects', () => rejected(observation(tracked.owner), 'ObservationV1', tracked));
check('GIT-ERROR: unreadable Git ownership cannot be treated as safe', () => rejected(observation(brokenGit.owner), 'ObservationV1', brokenGit));
check('PATH-ESCAPE: direct foreign, traversal and symlink targets reject', () => {
  for (const target of [join(outside, 'payload.json'), `${normal.root}/.sdd/context/../../foreign.json`,
    join(normal.root, '.sdd', 'context', 'escape', 'payload.json')]) {
    rejected(observation(normal.owner), 'ObservationV1', normal, { plannedPaths: [target] });
  }
});
check('HASH-PATH: authority membership cannot authorize foreign/escaping paths', () => {
  for (const path of [join(outside, 'tasks.md'), '../../foreign/tasks.md']) {
    const value = projection(); value.authorityHashes = [{ path, sha256: hash }]; rejected(value);
  }
});
check('REDACTION: admitted text is redacted before the in-memory result', () => {
  const value = observation(normal.owner);
  const credential = ['synthetic', 'credential'].join('-');
  value.text = `${['pass', 'word'].join('')}=${credential}`;
  const result = admit(value, 'ObservationV1');
  assert.equal(JSON.stringify(result).includes(credential), false);
  assert.equal(result.text.includes(['RE', 'DACTED'].join('')), true);
  assert.equal(['captured', 'safe'].includes(result.kind), false, 'validation claimed durable success');
});
check('DEADLINE: exhausted shared trusted budget rejects without a result', () => {
  rejected(observation(normal.owner), 'ObservationV1', normal, { deadline: performance.now() - 1 });
});

// Git OIDs are not the SHA-256 integrity-digest contract. Both fixtures use real
// Git commits; admission still does not establish current-HEAD freshness (T-003).
const headFixtures = [
  { format: 'sha1', f: sha1, head: sha1Head, other: normalHead, hint: 'sha256', size: 40 },
  { format: 'sha256', f: normal, head: normalHead, other: sha1Head, hint: 'sha1', size: 64 },
];
function withHead(f, head) { return { ...projection(), owner: { ...f.owner }, head }; }
test('HEAD-FIXTURE: real Git storage format and committed HEAD are observed', () => {
  for (const { format, f, head, size } of headFixtures) {
    assert.equal(git(f.root, 'rev-parse', '--show-object-format=storage').trim(), format);
    assert.equal(git(f.root, 'rev-parse', '--verify', 'HEAD').trim(), head);
    assert.equal(head.length, size);
    assert.match(head, /^[a-f0-9]+$/);
  }
  console.log(`Git fixture OIDs: sha1=${sha1Head}; sha256=${normalHead}`);
});
for (const { format, f, head, other, hint, size } of headFixtures) {
  check(`HEAD-VALID-${format}: real storage-format OID accepts despite a contradictory hint`, () => {
    const value = withHead(f, head);
    assert.deepEqual(validate(JSON.stringify(value), context('ProjectionV1', f, { objectFormat: hint })), value);
  });
  check(`HEAD-WRONG-FORMAT-${format}: another repository format cannot select the rule`, () => {
    rejected(withHead(f, other), 'ProjectionV1', f, { objectFormat: hint });
  });
  check(`HEAD-MALFORMED-${format}: abbreviated/overlong, uppercase and non-hex OIDs reject`, () => {
    for (const invalid of [head.slice(0, size - 1), head + '0', head.toUpperCase(), 'g' + head.slice(1)]) {
      rejected(withHead(f, invalid), 'ProjectionV1', f);
    }
  });
}
check('HEAD-CALLER-FORMAT: request cannot supply object-format authority', () => {
  const value = projection(); value.objectFormat = 'sha256'; rejected(value);
});
check('HEAD-UNSUPPORTED-GIT: real unsupported format configuration fails closed', () => {
  rejected(withHead(unsupportedGit, unsupportedHead), 'ProjectionV1', unsupportedGit);
});

// Reconcile admission uses the same real Git fixtures and shared entrance.
const reconcile = (owner = normal.owner) => ({ schemaVersion: 1, owner: { ...owner },
  kind: 'observable-transcript', coverage: 'complete', records: [observation(owner)] });
test('RECONCILE-FIXTURE: valid owner/observation reaches the shared Git/path boundary', () => {
  for (const f of [normal, sha1]) {
    assert.deepEqual(validate(JSON.stringify(f.owner), context('OwnerV1', f)), f.owner);
    const result = validate(JSON.stringify(observation(f.owner)), context('ObservationV1', f));
    assert.deepEqual(result.owner, f.owner);
    assert.equal(result.text, 'ordinary text');
    assert.equal(existsSync(f.target), false, 'admission created a store file');
  }
});
for (const kind of ['observable-transcript', 'compact-manual', 'compact-auto']) {
  for (const coverage of ['complete', 'partial', 'unavailable']) {
    check(`RECONCILE-VALID-${kind}-${coverage}: declared request and nested Observation enums accept`, () => {
      const value = { ...reconcile(), kind, coverage, stableEventId: 'reconcile-event' };
      value.records = ['prompt', 'final-assistant'].flatMap(kind =>
        ['complete', 'partial', 'unavailable'].map(coverage =>
          ({ ...observation(normal.owner), kind, coverage, stableEventId: 'observation-event' })));
      assert.deepEqual(admit(value, 'ReconcileV1'), value);
    });
  }
}
for (const coverage of ['complete', 'partial', 'unavailable']) {
  check(`RECONCILE-EMPTY-${coverage}: records has no invented nonempty requirement`, () => {
    const value = { ...reconcile(), coverage, records: [] };
    assert.deepEqual(admit(value, 'ReconcileV1'), value);
  });
}
check('RECONCILE-UNAVAILABLE: absent optional records accepts', () => {
  const value = { ...reconcile(), coverage: 'unavailable' }; delete value.records;
  assert.deepEqual(admit(value, 'ReconcileV1'), value);
});
for (const coverage of ['complete', 'partial']) {
  check(`RECONCILE-REQUIRED-${coverage}: missing records rejects`, () => {
    const value = { ...reconcile(), coverage }; delete value.records;
    rejected(value, 'ReconcileV1');
  });
}
check('RECONCILE-CLOSED: required fields, version, types and unknown keys reject', () => {
  for (const field of ['schemaVersion', 'owner', 'kind', 'coverage']) {
    const value = reconcile(); delete value[field]; rejected(value, 'ReconcileV1');
  }
  for (const change of [{ schemaVersion: 2 }, { schemaVersion: '1' }, { owner: null }, { owner: [] },
    { kind: 1 }, { coverage: false }, { extra: true }]) {
    rejected({ ...reconcile(), ...change }, 'ReconcileV1');
  }
  for (const value of [null, [], 1]) rejected(value, 'ReconcileV1');
});
check('RECONCILE-ENUM: unrelated kinds and case variants reject', () => {
  for (const kind of ['prompt', 'final-assistant', 'resume', 'Compact-auto', '']) {
    rejected({ ...reconcile(), kind }, 'ReconcileV1');
  }
  for (const coverage of ['Complete', 'unknown', '']) rejected({ ...reconcile(), coverage }, 'ReconcileV1');
});
check('RECONCILE-RECORDS: present records is always an Observation array', () => {
  for (const coverage of ['complete', 'partial', 'unavailable']) {
    for (const records of [null, {}, 'records', [null], [[]], [1]]) {
      rejected({ ...reconcile(), coverage, records }, 'ReconcileV1');
    }
  }
});
check('RECONCILE-OBSERVATION-CLOSED: every nested required field, type and enum is checked', () => {
  for (const field of Object.keys(observation(normal.owner))) {
    const value = reconcile(); delete value.records[0][field]; rejected(value, 'ReconcileV1');
  }
  for (const change of [{ schemaVersion: 2 }, { schemaVersion: '1' }, { owner: null }, { owner: [] },
    { kind: 'observable-transcript' }, { kind: 'Prompt' }, { kind: 1 }, { coverage: 'Complete' },
    { coverage: null }, { text: 1 }, { text: null }, { text: '\ud800' }, { extra: true }]) {
    const value = reconcile(); Object.assign(value.records[0], change); rejected(value, 'ReconcileV1');
  }
});
check('RECONCILE-OWNER: outer and nested owners cannot self-authorize', () => {
  for (const nested of [false, true]) {
    for (const field of Object.keys(normal.owner)) {
      const value = reconcile(); const owner = nested ? value.records[0].owner : value.owner;
      delete owner[field]; rejected(value, 'ReconcileV1');
    }
    for (const field of ['sddRoot', 'worktreeRoot', 'gitDirectory', 'featureId', 'host', 'sessionId']) {
      const value = reconcile(); const owner = nested ? value.records[0].owner : value.owner;
      owner[field] = field === 'host' ? 'claude' : 'foreign'; rejected(value, 'ReconcileV1');
    }
    for (const change of [{ schemaVersion: 2 }, { schemaVersion: '1' }, { extra: true }]) {
      const value = reconcile(); Object.assign(nested ? value.records[0].owner : value.owner, change);
      rejected(value, 'ReconcileV1');
    }
  }
});
check('RECONCILE-ID-1024: outer and nested IDs accept the existing UTF-8 boundary', () => {
  for (const id of ['x'.repeat(1024), '🙂'.repeat(256)]) {
    const value = reconcile(); value.stableEventId = id; value.records[0].stableEventId = id;
    const result = admit(value, 'ReconcileV1');
    assert.equal(result.stableEventId, id); assert.equal(result.records[0].stableEventId, id);
  }
});
check('RECONCILE-ID-INVALID: outer and nested ID types/Unicode/byte limits reject', () => {
  for (const nested of [false, true]) {
    for (const id of ['', null, 1, 'x'.repeat(1025), '🙂'.repeat(256) + 'x', '\ud800']) {
      const value = reconcile(); (nested ? value.records[0] : value).stableEventId = id;
      rejected(value, 'ReconcileV1');
    }
  }
});
check('RECONCILE-REDACTION: every nested text is prepared before returning any output', () => {
  const credential = ['synthetic', 'credential'].join('-');
  for (const coverage of ['complete', 'partial', 'unavailable']) {
    const value = { ...reconcile(), coverage };
    value.records[0].text = `${['pass', 'word'].join('')}=${credential}`;
    value.records.push({ ...observation(normal.owner), kind: 'final-assistant',
      text: `${['Author', 'ization'].join('')}: Bearer ${credential}` }, observation(normal.owner));
    const result = admit(value, 'ReconcileV1');
    assert.equal(JSON.stringify(result).includes(credential), false);
    for (const record of result.records.slice(0, 2)) assert.ok(record.text.includes(['RE', 'DACTED'].join('')));
    assert.equal(result.records[2].text, 'ordinary text');
    assert.equal(value.records[0].text.includes(credential), true, 'caller input was mutated');
    assert.equal(existsSync(normal.target), false, 'admission claimed persistence');
  }
});
check('RECONCILE-AUTHORITY: outer and nested receipt/path/budget/lifecycle fields reject', () => {
  for (const nested of [false, true]) {
    for (const field of ['receivedAtUtc', 'sequence', 'expiry', 'plannedPaths', 'deadline', 'budget',
      'taskLifecycle', 'storeRoot', 'host', 'eventKind', 'transcriptLocator', 'omission', 'ruleVersion']) {
      const value = reconcile(); (nested ? value.records[0] : value)[field] = 'caller';
      rejected(value, 'ReconcileV1');
    }
  }
});
check('RECONCILE-JSON: malformed, decoded-duplicate and surrogate input rejects', () => {
  const source = JSON.stringify(reconcile());
  for (const raw of [source.slice(0, -1), source.replace('"schemaVersion":1', '"schemaVersion":1,"schemaVersion":1'),
    source.replace('"text":"ordinary text"', '"text":"ordinary text","te\\u0078t":"duplicate"'), undefined]) {
    rejected(raw, 'ReconcileV1', normal, {}, true);
  }
});
check('RECONCILE-DEADLINE: exhausted original trusted budget returns no result', () => {
  rejected(reconcile(), 'ReconcileV1', normal, { deadline: performance.now() - 1 });
});
check('RECONCILE-PATH: missing/negated ignore, tracked target and Git error fail closed', () => {
  for (const f of [missingIgnore, negatedIgnore, tracked, brokenGit]) {
    rejected(reconcile(f.owner), 'ReconcileV1', f);
  }
  for (const target of [join(outside, 'payload.json'), `${normal.root}/.sdd/context/../../foreign.json`,
    join(normal.root, '.sdd', 'context', 'escape', 'payload.json')]) {
    rejected(reconcile(), 'ReconcileV1', normal, { plannedPaths: [target] });
  }
});
check('RECONCILE-UNKNOWN-TYPE: request spelling cannot open an unknown trusted contract', () => {
  for (const type of ['ReconcileV2', 'reconcilev1', 'unknown', '', null, 1]) rejected(reconcile(), type);
});

const resume = (owner = normal.owner) => ({ schemaVersion: 1, owner: { ...owner }, kind: 'resume' });
const cleanup = (registrationId = 'registration') => ({ schemaVersion: 1, registrationId });
check('RESUME-VALID: same-owner request without predecessor returns only the input', () => {
  const value = resume();
  assert.deepEqual(admit(value, 'ResumeV1'), value);
  assert.equal(existsSync(normal.target), false, 'admission created a store file');
});
for (const [label, id] of [['1-BYTE', 'x'], ['1024-ASCII', 'x'.repeat(1024)], ['1024-UTF8', '🙂'.repeat(256)]]) {
  check(`CLEANUP-VALID-${label}: bounded opaque ID returns only the input without cleanup`, () => {
    const value = cleanup(id);
    assert.deepEqual(admit(value, 'CleanupV1'), value);
    assert.equal(existsSync(normal.target), false, 'admission created a store file');
    assert.equal(existsSync(tracked.target), true, 'admission deleted a store file');
  });
}
check('RESUME-CLEANUP-CLOSED: required fields, object types, version and extra keys reject', () => {
  for (const [type, make] of [['ResumeV1', resume], ['CleanupV1', cleanup]]) {
    for (const field of Object.keys(make())) {
      const value = make(); delete value[field]; rejected(value, type);
    }
    for (const value of [null, [], 'request', 1]) rejected(value, type);
    for (const schemaVersion of [0, 2, '1', null]) rejected({ ...make(), schemaVersion }, type);
    rejected({ ...make(), extra: true }, type);
  }
});
check('RESUME-KIND: only the exact resume discriminant and an object owner are valid', () => {
  for (const kind of ['Resume', 'prompt', '', null, 1]) rejected({ ...resume(), kind }, 'ResumeV1');
  for (const owner of [null, [], 'owner', 1]) rejected({ ...resume(), owner }, 'ResumeV1');
});
check('RESUME-OWNER: closed owner cannot authorize a foreign path, feature, host or session', () => {
  for (const field of Object.keys(normal.owner)) {
    const value = resume(); delete value.owner[field]; rejected(value, 'ResumeV1');
  }
  for (const field of ['sddRoot', 'worktreeRoot', 'gitDirectory']) {
    const value = resume(); value.owner[field] = sha1.owner[field]; rejected(value, 'ResumeV1');
  }
  for (const field of ['featureId', 'host', 'sessionId']) {
    const value = resume(); value.owner[field] = field === 'host' ? 'claude' : 'foreign';
    rejected(value, 'ResumeV1');
  }
  for (const change of [{ schemaVersion: 2 }, { schemaVersion: '1' }, { extra: true }]) {
    const value = resume(); Object.assign(value.owner, change); rejected(value, 'ResumeV1');
  }
});
check('RESUME-PREDECESSOR: even a plausible ID cannot supply independent relationship proof', () => {
  for (const predecessorSessionId of [normal.owner.sessionId, 'foreign-session', 'x'.repeat(1024),
    '', 'x'.repeat(1025), null, 1, '\ud800']) {
    rejected({ ...resume(), predecessorSessionId }, 'ResumeV1');
  }
});
check('CLEANUP-ID-INVALID: ID type, Unicode and UTF-8 byte overflow reject', () => {
  for (const id of ['', null, 1, false, [], {}, 'x'.repeat(1025), '🙂'.repeat(256) + 'x', '\ud800']) {
    rejected(cleanup(id), 'CleanupV1');
  }
});
check('RESUME-CLEANUP-AUTHORITY: caller receipt/path/time/budget/lifecycle fields reject', () => {
  for (const [type, make] of [['ResumeV1', resume], ['CleanupV1', cleanup]]) {
    for (const field of ['receivedAtUtc', 'sequence', 'expiry', 'path', 'cleanupPaths', 'plannedPaths',
      'deadline', 'budget', 'taskLifecycle', 'storeRoot', 'checkedAtUtc', 'completed']) {
      rejected({ ...make(), [field]: 'caller' }, type);
    }
  }
  rejected({ ...cleanup(), owner: { ...normal.owner } }, 'CleanupV1');
  rejected({ ...cleanup(), kind: 'cleanup' }, 'CleanupV1');
});
check('RESUME-CLEANUP-JSON: malformed and decoded-duplicate fields reject', () => {
  for (const [type, make] of [['ResumeV1', resume], ['CleanupV1', cleanup]]) {
    const source = JSON.stringify(make());
    for (const raw of [source.slice(0, -1), source.replace('"schemaVersion":1',
      '"schemaVersion":1,"schema\\u0056ersion":1')]) rejected(raw, type, normal, {}, true);
  }
});
check('RESUME-CLEANUP-DEADLINE: the original exhausted trusted budget returns no result', () => {
  for (const [type, make] of [['ResumeV1', resume], ['CleanupV1', cleanup]]) {
    rejected(make(), type, normal, { deadline: performance.now() - 1 });
  }
});
check('RESUME-CLEANUP-PATH: existing ignore/tracked/Git/escape rejections remain required', () => {
  for (const type of ['ResumeV1', 'CleanupV1']) {
    for (const f of [missingIgnore, negatedIgnore, tracked, brokenGit]) {
      rejected(type === 'ResumeV1' ? resume(f.owner) : cleanup(), type, f);
    }
    for (const target of [join(outside, 'payload.json'), `${normal.root}/.sdd/context/../../foreign.json`,
      join(normal.root, '.sdd', 'context', 'escape', 'payload.json')]) {
      rejected(type === 'ResumeV1' ? resume() : cleanup(), type, normal, { plannedPaths: [target] });
    }
  }
});

const header = (owner = normal.owner) => ({ schemaVersion: 1, owner: { ...owner },
  segmentId: 'segment', firstSequence: 0, predecessorHash: hash });
const singleDecision = (owner = normal.owner) => ({ schemaVersion: 1, owner: { ...owner },
  id: 'decision', status: 'accepted', text: 'ordinary text', doNotReopen: false,
  sourceSequences: [0], originalReceipts: ['2026-09-29T00:00:00Z'] });
check('HEADER-VALID: bounded segment and safe sequence admit only a non-null hash header', () => {
  for (const segmentId of ['x', 'x'.repeat(1024), '🙂'.repeat(256)]) {
    for (const firstSequence of [0, Number.MAX_SAFE_INTEGER]) {
      const value = { ...header(), segmentId, firstSequence };
      assert.deepEqual(admit(value, 'JournalHeaderV1'), value);
    }
  }
  assert.equal(existsSync(normal.target), false, 'header admission created a store file');
});
check('HEADER-FIELDS: opaque segment, safe sequence and non-null lowercase digest are required', () => {
  for (const segmentId of ['', null, 1, [], {}, 'x'.repeat(1025), '🙂'.repeat(256) + 'x', '\ud800']) {
    rejected({ ...header(), segmentId }, 'JournalHeaderV1');
  }
  for (const firstSequence of [-1, 0.5, Number.MAX_SAFE_INTEGER + 1, '0', null]) {
    rejected({ ...header(), firstSequence }, 'JournalHeaderV1');
  }
  for (const predecessorHash of [null, 1, 'A'.repeat(64), 'a'.repeat(63), 'a'.repeat(65), 'g'.repeat(64)]) {
    rejected({ ...header(), predecessorHash }, 'JournalHeaderV1');
  }
});
check('DECISION-VALID: standalone status variants retain corresponding source references', () => {
  for (const status of ['accepted', 'rejected', 'superseded', 'constraint', 'open']) {
    const value = { ...singleDecision(), status };
    assert.deepEqual(admit(value, 'DecisionV1'), value);
  }
  assert.equal(existsSync(normal.target), false, 'decision admission created a store file');
});
check('DECISION-REDACTION: standalone text is redacted with optional owned materialization', () => {
  const credential = ['synthetic', 'decision', 'credential'].join('-');
  const value = { ...singleDecision(), id: '🙂'.repeat(256), doNotReopen: true,
    text: ['pass', 'word'].join('') + '=' + credential,
    sourceSequences: [0, Number.MAX_SAFE_INTEGER],
    originalReceipts: ['2026-09-29T00:00:00Z', '2026-09-29T00:00:01Z'],
    materialization: { path: '.sdd/context/decision.md', sha256: hash } };
  const result = admit(value, 'DecisionV1');
  assert.equal(JSON.stringify(result).includes(credential), false);
  assert.equal(result.text.includes(['RE', 'DACTED'].join('')), true);
  assert.deepEqual(result, { ...value, text: result.text });
  assert.equal(existsSync(join(normal.root, value.materialization.path)), false,
    'decision admission wrote materialization');
});
check('DECISION-FIELDS: ID/status/text/boolean and corresponding nonempty references are checked', () => {
  for (const change of [{ id: '' }, { id: 1 }, { id: 'x'.repeat(1025) }, { id: '\ud800' },
    { status: 'Accepted' }, { status: 'unknown' }, { text: null }, { text: 1 }, { text: '\ud800' },
    { doNotReopen: 'true' }, { doNotReopen: 1 }, { sourceSequences: {} }, { sourceSequences: [] },
    { sourceSequences: [-1] }, { sourceSequences: [0.5] },
    { sourceSequences: [Number.MAX_SAFE_INTEGER + 1] }, { sourceSequences: ['0'] },
    { sourceSequences: [0, 1] }, { originalReceipts: {} }, { originalReceipts: [] },
    { originalReceipts: ['2026-09-29T00:00:00Z', '2026-09-29T00:00:01Z'] },
    { originalReceipts: [1] }, { originalReceipts: ['2026-02-30T00:00:00Z'] },
    { originalReceipts: ['2026-09-29T00:00:00+01:00'] }]) {
    rejected({ ...singleDecision(), ...change }, 'DecisionV1');
  }
});
check('DECISION-MATERIALIZATION: optional reference is closed, owned and uses an integrity digest', () => {
  for (const materialization of [null, [], {}, { path: 'p' }, { sha256: hash },
    { path: 'p', sha256: hash, extra: true }, { path: 1, sha256: hash },
    { path: '', sha256: hash }, { path: join(outside, 'decision.md'), sha256: hash },
    { path: '../../decision.md', sha256: hash },
    { path: '.sdd/context/escape/decision.md', sha256: hash },
    { path: 'p', sha256: 'A'.repeat(64) }, { path: 'p', sha256: 'a'.repeat(63) },
    { path: 'p', sha256: 'g'.repeat(64) }, { path: 'p', sha256: null }]) {
    rejected({ ...singleDecision(), materialization }, 'DecisionV1');
  }
});
check('HEADER-DECISION-CLOSED: every required field, type, version and extra key is checked', () => {
  for (const [type, make] of [['JournalHeaderV1', header], ['DecisionV1', singleDecision]]) {
    for (const field of Object.keys(make())) {
      const value = make(); delete value[field]; rejected(value, type);
    }
    for (const value of [null, [], 'entity', 1]) rejected(value, type);
    for (const schemaVersion of [0, 2, '1', null]) rejected({ ...make(), schemaVersion }, type);
    for (const field of ['extra', 'synced', 'kind', 'deadline', 'plannedPaths']) {
      rejected({ ...make(), [field]: true }, type);
    }
  }
});
check('HEADER-DECISION-OWNER: closed owner independently rejects every foreign tuple component', () => {
  for (const [type, make] of [['JournalHeaderV1', header], ['DecisionV1', singleDecision]]) {
    for (const owner of [null, [], 'owner', 1]) rejected({ ...make(), owner }, type);
    for (const field of Object.keys(normal.owner)) {
      const value = make(); delete value.owner[field]; rejected(value, type);
    }
    for (const field of ['sddRoot', 'worktreeRoot', 'gitDirectory']) {
      const value = make(); value.owner[field] = sha1.owner[field]; rejected(value, type);
    }
    for (const field of ['featureId', 'host', 'sessionId']) {
      const value = make(); value.owner[field] = field === 'host' ? 'claude' : 'foreign'; rejected(value, type);
    }
    for (const change of [{ schemaVersion: 2 }, { schemaVersion: '1' }, { extra: true }]) {
      const value = make(); Object.assign(value.owner, change); rejected(value, type);
    }
  }
});
check('HEADER-DECISION-JSON: malformed and decoded-duplicate keys return no result', () => {
  for (const [type, make] of [['JournalHeaderV1', header], ['DecisionV1', singleDecision]]) {
    const source = JSON.stringify(make());
    for (const raw of [source.slice(0, -1), source.replace('"schemaVersion":1',
      '"schemaVersion":1,"schema\\u0056ersion":1')]) rejected(raw, type, normal, {}, true);
  }
});
check('HEADER-DECISION-DEADLINE: an exhausted original trusted budget rejects', () => {
  for (const [type, make] of [['JournalHeaderV1', header], ['DecisionV1', singleDecision]]) {
    rejected(make(), type, normal, { deadline: performance.now() - 1 });
  }
});
check('HEADER-DECISION-PATH: shared ignore/tracked/Git and escaping path controls remain required', () => {
  for (const [type, make] of [['JournalHeaderV1', header], ['DecisionV1', singleDecision]]) {
    for (const f of [missingIgnore, negatedIgnore, tracked, brokenGit]) rejected(make(f.owner), type, f);
    for (const target of [join(outside, 'payload.json'), normal.root + '/.sdd/context/../../foreign.json',
      join(normal.root, '.sdd', 'context', 'escape', 'payload.json')]) {
      rejected(make(), type, normal, { plannedPaths: [target] });
    }
  }
});
check('LOCK-V1-PID-INVALID: non-positive unsafe and wrong-type PID values reject', () => {
  for (const pid of [null, 0, -1, 1.5, '1', true, Number.MAX_SAFE_INTEGER + 1, {}, []]) {
    rejected({ schemaVersion: 1, owner: { ...normal.owner }, nonce: 'nonce',
      pid, processStartIdentity: 'process-start' }, 'LockV1');
  }
});

const registryEntry = (f = normal) => ({ owner: { ...f.owner },
  storeRoot: realpathSync.native(join(f.root, '.sdd', 'context')), registrationId: 'registration',
  schedulerState: 'enabled', checkedAtUtc: '2026-09-29T00:00:00Z' });
check('REGISTRY-ENTRY-VALID: exact owned entry admits every state and bounded opaque ID', () => {
  for (const schedulerState of ['enabled', 'disabled', 'failed']) {
    for (const registrationId of ['r', 'x'.repeat(1024), '🙂'.repeat(256)]) {
      const value = { ...registryEntry(), schedulerState, registrationId };
      assert.deepEqual(admit(value, 'RegistryEntryV1'), value);
    }
  }
  assert.equal(existsSync(normal.target), false, 'registry entry admission created a store file');
});
check('REGISTRY-ENTRY-CLOSED: five fields are required and object extensions reject', () => {
  for (const field of Object.keys(registryEntry())) {
    const value = registryEntry(); delete value[field]; rejected(value, 'RegistryEntryV1');
  }
  for (const value of [null, [], 'entry', 1]) rejected(value, 'RegistryEntryV1');
  for (const field of ['schemaVersion', 'entries', 'maxObservedUtc', 'text', 'deadline', 'plannedPaths']) {
    rejected({ ...registryEntry(), [field]: true }, 'RegistryEntryV1');
  }
});
check('REGISTRY-ENTRY-FIELDS: locator types, ID bounds, exact states and UTC dates are checked', () => {
  for (const storeRoot of ['', null, 1, [], {}]) rejected({ ...registryEntry(), storeRoot }, 'RegistryEntryV1');
  for (const registrationId of ['', null, 1, [], {}, 'x'.repeat(1025), '🙂'.repeat(256) + 'x', '\ud800']) {
    rejected({ ...registryEntry(), registrationId }, 'RegistryEntryV1');
  }
  for (const schedulerState of ['', 'unknown', 'Enabled', 'Disabled', 'Failed', null, 1, [], {}]) {
    rejected({ ...registryEntry(), schedulerState }, 'RegistryEntryV1');
  }
  for (const checkedAtUtc of ['', null, 1, [], {}, '2026-02-30T00:00:00Z',
    '2026-09-29T24:00:00Z', '2026-09-29T00:00:00', '2026-09-29T00:00:00+00:00']) {
    rejected({ ...registryEntry(), checkedAtUtc }, 'RegistryEntryV1');
  }
});
check('REGISTRY-ENTRY-OWNER: every foreign tuple component and malformed owner rejects', () => {
  for (const owner of [null, [], 'owner', 1]) rejected({ ...registryEntry(), owner }, 'RegistryEntryV1');
  for (const field of Object.keys(normal.owner)) {
    const value = registryEntry(); delete value.owner[field]; rejected(value, 'RegistryEntryV1');
  }
  for (const field of ['sddRoot', 'worktreeRoot', 'gitDirectory']) {
    const value = registryEntry(); value.owner[field] = sha1.owner[field]; rejected(value, 'RegistryEntryV1');
  }
  for (const field of ['featureId', 'host', 'sessionId']) {
    const value = registryEntry(); value.owner[field] = field === 'host' ? 'claude' : 'foreign';
    rejected(value, 'RegistryEntryV1');
  }
  for (const change of [{ schemaVersion: 2 }, { schemaVersion: '1' }, { extra: true }]) {
    const value = registryEntry(); Object.assign(value.owner, change); rejected(value, 'RegistryEntryV1');
  }
});
check('REGISTRY-ENTRY-STORE: only the exact canonical owned context locator is admitted', () => {
  for (const storeRoot of [normal.root, join(normal.root, '.git'), normal.target,
    join(normal.root, '.sdd', 'context', 'child'), join(sha1.root, '.sdd', 'context'), outside,
    normal.root + '/.sdd/context/../../../outside', join(normal.root, '.sdd', 'context', 'escape')]) {
    rejected({ ...registryEntry(), storeRoot }, 'RegistryEntryV1');
  }
});
check('REGISTRY-ENTRY-REPLACED-STORE: a temporary context replaced by an escaping symlink rejects', () => {
  const f = fixture('registry-replaced-store');
  const value = registryEntry(f);
  const store = join(f.root, '.sdd', 'context');
  rmSync(store, { recursive: true }); symlinkSync(outside, store);
  assert.equal(realpathSync(store), outside, 'store replacement fixture did not escape');
  rejected(value, 'RegistryEntryV1', f);
});
check('REGISTRY-ENTRY-JSON: malformed and decoded duplicate entry keys reject', () => {
  const source = JSON.stringify(registryEntry());
  for (const raw of [source.slice(0, -1), source.replace('"registrationId":"registration"',
    '"registrationId":"registration","registration\\u0049d":"registration"')]) {
    rejected(raw, 'RegistryEntryV1', normal, {}, true);
  }
});
check('REGISTRY-ENTRY-DEADLINE: the existing exhausted trusted budget returns no entry', () => {
  rejected(registryEntry(), 'RegistryEntryV1', normal, { deadline: performance.now() - 1 });
});
check('REGISTRY-ENTRY-PATH: shared ignore/tracked/Git and escaping planned targets still reject', () => {
  for (const f of [missingIgnore, negatedIgnore, tracked, brokenGit]) rejected(registryEntry(f), 'RegistryEntryV1', f);
  for (const target of [join(outside, 'entry.json'), normal.root + '/.sdd/context/../../foreign.json',
    join(normal.root, '.sdd', 'context', 'escape', 'entry.json')]) {
    rejected(registryEntry(), 'RegistryEntryV1', normal, { plannedPaths: [target] });
  }
});

function rejectPreparation(value, f, extra = {}) {
  assert.equal(typeof prepareStore, 'function', 'new private store preparation is not implemented');
  let caught;
  try { prepareStore(JSON.stringify(value), context('OwnerV1', f, extra)); } catch (error) { caught = error; }
  assert.ok(caught instanceof Error, 'preparation failure returned success');
  assert.deepEqual(Object.keys(caught), ['code']);
  assert.match(caught.code, /^[a-z][a-z-]*$/);
  assert.equal(caught.message, caught.code);
  assert.equal(caught.stack, undefined); assert.equal(caught.cause, undefined);
}
test('NEW-STORE-VALID: fresh empty directory is private even under permissive POSIX umask',
  { skip: process.platform === 'win32' }, () => {
  assert.equal(typeof validate, 'function', 'shared validate API is not implemented');
  assert.equal(typeof prepareStore, 'function', 'new private store preparation is not implemented');
  assert.equal(typeof process.getuid, 'function', 'this fixture requires a POSIX owning-account lane');
  const f = fixture('new-store-valid'); const store = join(f.root, '.sdd', 'context');
  rmSync(store, { recursive: true });
  const priorMask = process.umask(0);
  try {
    assert.deepEqual(prepareStore(JSON.stringify(f.owner), context('OwnerV1', f)), f.owner);
    const created = statSync(store);
    assert.ok(created.isDirectory()); assert.equal(created.mode & 0o777, 0o700);
    assert.equal(created.uid, process.getuid()); assert.equal(realpathSync(store), store);
    assert.equal(existsSync(f.target), false, 'empty preparation wrote a content file');
  } finally { process.umask(priorMask); }
});
test('NEW-STORE-NATIVE-DEADLINE: complete fresh preparation fits the shared core budget', () => {
  const f = fixture('new-store-native-deadline');
  const store = join(f.root, '.sdd', 'context');
  rmSync(store, { recursive: true });
  const trusted = context('OwnerV1', f);
  const started = performance.now();
  const result = prepareStore(JSON.stringify(f.owner), trusted);
  const elapsed = performance.now() - started;
  assert.deepEqual(result, f.owner);
  assert.ok(elapsed <= 1000, 'complete preparation exceeded the shared core budget');
  assert.ok(statSync(store).isDirectory());
  assert.equal(existsSync(f.target), false, 'empty preparation wrote a content file');
  console.log(`native ${process.platform} prepareStore elapsed_ms=${elapsed.toFixed(1)}`);
});
check('NEW-STORE-EXISTING: refusal preserves existing directory mode identity and contents', () => {
  const f = fixture('new-store-existing'); const store = join(f.root, '.sdd', 'context');
  writeFileSync(f.target, 'ordinary synthetic fixture'); const before = statSync(store);
  rejectPreparation(f.owner, f);
  const after = statSync(store);
  assert.equal(after.mode, before.mode); assert.equal(after.ino, before.ino); assert.equal(after.dev, before.dev);
  assert.equal(readFileSync(f.target, 'utf8'), 'ordinary synthetic fixture');
});
check('NEW-STORE-INVALID: malformed or foreign owner cannot create a directory', () => {
  const f = fixture('new-store-invalid'); const store = join(f.root, '.sdd', 'context');
  rmSync(store, { recursive: true });
  for (const value of [{ ...f.owner, extra: true }, normal.owner]) {
    rejectPreparation(value, f); assert.equal(existsSync(store), false);
  }
});
check('NEW-STORE-ESCAPE: escaping parent cannot create outside the owned worktree', () => {
  const f = fixture('new-store-escape'); const parent = join(f.root, '.sdd');
  const destination = join(scratch, 'new-store-outside'); mkdirSync(destination);
  rmSync(parent, { recursive: true }); symlinkSync(destination, parent);
  rejectPreparation(f.owner, f);
  assert.equal(existsSync(join(destination, 'context')), false);
});
check('NEW-STORE-GUARDS: ignore Git and expired budget failures leave no new store', () => {
  for (const [name, ignored, broken, expired] of [
    ['new-store-ignore', false, false, false], ['new-store-git', true, true, false],
    ['new-store-budget', true, false, true]]) {
    const f = fixture(name, ignored); const store = join(f.root, '.sdd', 'context');
    rmSync(store, { recursive: true }); if (broken) rmSync(join(f.root, '.git'), { recursive: true });
    rejectPreparation(f.owner, f, expired ? { deadline: performance.now() - 1 } : {});
    assert.equal(existsSync(store), false);
  }
});

const lockValue = (owner = normal.owner) => ({ schemaVersion: 1, owner: { ...owner },
  nonce: 'nonce', pid: 1, processStartIdentity: 'process-start' });
for (const [label, pid] of [['1', 1], ['MAX', Number.MAX_SAFE_INTEGER]]) {
  check(`LOCK-V1-PID-${label}: inclusive endpoint and exact opaque byte bounds admit`, () => {
    const value = { ...lockValue(), pid, nonce: 'x'.repeat(1024), processStartIdentity: '🙂'.repeat(256) };
    assert.deepEqual(admit(value, 'LockV1'), value);
  });
}
check('LOCK-V1-CLOSED: all five fields are required and unknown keys or versions reject', () => {
  for (const field of Object.keys(lockValue())) {
    const value = lockValue(); delete value[field]; rejected(value, 'LockV1');
  }
  for (const value of [null, [], { ...lockValue(), schemaVersion: 2 },
    { ...lockValue(), schemaVersion: '1' }, { ...lockValue(), extra: true }]) rejected(value, 'LockV1');
});
check('LOCK-V1-OWNER: every independently trusted owner field must match', () => {
  for (const [field, foreign] of [['schemaVersion', 2], ['sddRoot', outside], ['worktreeRoot', outside],
    ['gitDirectory', outside], ['featureId', 'foreign'], ['host', 'claude'], ['sessionId', 'foreign']]) {
    const value = lockValue(); value.owner[field] = foreign; rejected(value, 'LockV1');
  }
});
check('LOCK-V1-ID: nonce and start identity independently enforce the opaque contract', () => {
  for (const field of ['nonce', 'processStartIdentity']) {
    for (const id of ['', 'x'.repeat(1025), '🙂'.repeat(256) + 'x', '\ud800', 1, []]) {
      const value = lockValue(); value[field] = id; rejected(value, 'LockV1');
    }
  }
});
check('LOCK-V1-JSON: malformed or decoded duplicate Lock members reject', () => {
  const source = JSON.stringify(lockValue());
  for (const raw of [source.slice(0, -1), source.replace('"pid":1', '"pid":1,"p\\u0069d":1')]) {
    rejected(raw, 'LockV1', normal, {}, true);
  }
});
check('LOCK-V1-GUARDS: shared deadline Git and planned-path failures still reject', () => {
  rejected(lockValue(), 'LockV1', normal, { deadline: performance.now() - 1 });
  for (const f of [missingIgnore, negatedIgnore, tracked, brokenGit]) rejected(lockValue(f.owner), 'LockV1', f);
  for (const target of [join(outside, 'lock.json'), normal.root + '/.sdd/context/../../foreign.json',
    join(normal.root, '.sdd', 'context', 'escape', 'lock.json')]) {
    rejected(lockValue(), 'LockV1', normal, { plannedPaths: [target] });
  }
});

const journalRecord = (owner = normal.owner) => ({ schemaVersion: 1, owner: { ...owner },
  sequence: 0, kind: 'prompt', receivedAtUtc: '2026-09-29T00:00:00Z', text: 'ordinary text',
  ruleVersion: 1, omission: false, coverage: 'complete', previousHash: hash, hash });
const journalKinds = ['prompt', 'final-assistant', 'observable-transcript', 'compact-manual', 'compact-auto', 'resume'];
for (const kind of journalKinds) {
  check(`JOURNAL-VALID-${kind}: exact kind and both safe sequence endpoints admit`, () => {
    for (const sequence of [0, Number.MAX_SAFE_INTEGER]) {
      const value = { ...journalRecord(), kind, sequence };
      assert.deepEqual(admit(value, 'JournalRecordV1'), value);
    }
    assert.equal(existsSync(normal.target), false, 'record admission created a store file');
  });
}
check('JOURNAL-OPTIONAL: coverage variants and absent or bounded opaque ID admit', () => {
  for (const [coverage, stableEventId] of [['complete', undefined], ['partial', 'event'],
    ['unavailable', 'x'.repeat(1024)], ['complete', '🙂'.repeat(256)]]) {
    const value = { ...journalRecord(), coverage, text: '', receivedAtUtc: '2026-09-29T00:00:00.123Z' };
    if (stableEventId !== undefined) value.stableEventId = stableEventId;
    assert.deepEqual(admit(value, 'JournalRecordV1'), value);
  }
});
check('JOURNAL-CLOSED: every required field and object extension is checked', () => {
  for (const field of Object.keys(journalRecord())) {
    const value = journalRecord(); delete value[field]; rejected(value, 'JournalRecordV1');
  }
  for (const value of [null, [], 'record', 1, true]) rejected(value, 'JournalRecordV1');
  for (const field of ['extra', 'host', 'sessionId', 'deadline', 'plannedPaths', 'synced']) {
    rejected({ ...journalRecord(), [field]: true }, 'JournalRecordV1');
  }
});
check('JOURNAL-FIELDS: independent scalar types enums ranges Unicode dates and digests reject', () => {
  for (const [field, invalid] of [
    ['schemaVersion', [0, 2, '1', null, true, [], {}]],
    ['sequence', [-1, 0.5, Number.MAX_SAFE_INTEGER + 1, '0', null, true, [], {}]],
    ['kind', ['', 'unknown', ...journalKinds.map(kind => kind[0].toUpperCase() + kind.slice(1)), null, 1, false, [], {}]],
    ['receivedAtUtc', ['', null, 1, false, [], {}, '2026-02-30T00:00:00Z', '2026-09-29T24:00:00Z',
      '2026-09-29T00:00:60Z', '2026-09-29T00:00:00', '2026-09-29T00:00:00+00:00', '2026-09-29T00:00:00z']],
    ['text', [null, 1, false, [], {}, '\ud800']],
    ['ruleVersion', [0, 2, '1', null, true, [], {}]],
    ['omission', [null, 0, 1, 'false', [], {}]],
    ['coverage', ['', 'unknown', 'Complete', 'Partial', 'Unavailable', null, 1, false, [], {}]],
    ['stableEventId', ['', null, 1, false, [], {}, 'x'.repeat(1025), '🙂'.repeat(256) + 'x', '\ud800']],
  ]) {
    for (const item of invalid) rejected({ ...journalRecord(), [field]: item }, 'JournalRecordV1');
  }
  for (const field of ['previousHash', 'hash']) {
    for (const item of [null, 1, false, [], {}, 'A'.repeat(64), 'a'.repeat(63), 'a'.repeat(65), 'g'.repeat(64)]) {
      rejected({ ...journalRecord(), [field]: item }, 'JournalRecordV1');
    }
  }
});
check('JOURNAL-OWNER: closed canonical owner independently rejects every foreign component', () => {
  for (const owner of [null, [], 'owner', 1]) rejected({ ...journalRecord(), owner }, 'JournalRecordV1');
  for (const field of Object.keys(normal.owner)) {
    const value = journalRecord(); delete value.owner[field]; rejected(value, 'JournalRecordV1');
  }
  for (const field of ['sddRoot', 'worktreeRoot', 'gitDirectory']) {
    const value = journalRecord(); value.owner[field] = sha1.owner[field]; rejected(value, 'JournalRecordV1');
  }
  for (const field of ['featureId', 'host', 'sessionId']) {
    const value = journalRecord(); value.owner[field] = field === 'host' ? 'claude' : 'foreign';
    rejected(value, 'JournalRecordV1');
  }
  for (const change of [{ schemaVersion: 2 }, { schemaVersion: '1' }, { extra: true }]) {
    const value = journalRecord(); Object.assign(value.owner, change); rejected(value, 'JournalRecordV1');
  }
});

const journalSecret = ['synthetic', 'journal', 'credential'].join('-');
const journalKey = ['pass', 'word'].join('');
const journalSensitive = [
  ['pem', `-----${'BE' + 'GIN'} PRIVATE KEY-----\n${journalSecret}\n-----${'E' + 'ND'} PRIVATE KEY-----`],
  ['assignment', `${journalKey}=${journalSecret}`],
  ['header', `${['Author', 'ization'].join('')}: ${['Bear', 'er'].join('')} ${journalSecret}`],
  ['url', `https://user:${journalSecret}@example.invalid/a]b`],
  ['token', ['s', 'k-'].join('') + journalSecret],
  ['jwt', ['a'.repeat(8), journalSecret, 'b'.repeat(8)].join('.')],
];
check('JOURNAL-TEXT-REJECT: six raw families and marker suffixes must reject without repair', () => {
  for (const [family, text] of journalSensitive) {
    rejected({ ...journalRecord(), text }, 'JournalRecordV1');
    const marker = `[${['RE', 'DACTED'].join('')}:${family}]`;
    rejected({ ...journalRecord(), text: `${journalKey}=${marker}${journalSecret}` }, 'JournalRecordV1');
  }
});
check('JOURNAL-PRESERVE: actual six-family output hash and either omission value remain exact', () => {
  for (const [family, raw] of journalSensitive) {
    const text = journalRedact(raw, context('JournalRecordV1').deadline).text;
    assert.equal(text.includes(journalSecret), false);
    assert.equal(text.includes(`[${['RE', 'DACTED'].join('')}:${family}]`), true);
    for (const omission of [false, true]) {
      const value = { ...journalRecord(), text, omission };
      const before = JSON.stringify(value);
      assert.deepEqual(admit(value, 'JournalRecordV1'), value);
      assert.equal(JSON.stringify(value), before, 'record admission mutated caller input');
    }
  }
});
check('JOURNAL-JSON-GUARDS: shared JSON deadline Git and planned-path checks remain required', () => {
  const source = JSON.stringify(journalRecord());
  for (const raw of [source.slice(0, -1), source.replace('"sequence":0', '"sequence":0,"sequ\\u0065nce":0')]) {
    rejected(raw, 'JournalRecordV1', normal, {}, true);
  }
  rejected(journalRecord(), 'JournalRecordV1', normal, { deadline: performance.now() - 1 });
  for (const f of [missingIgnore, negatedIgnore, tracked, brokenGit]) rejected(journalRecord(f.owner), 'JournalRecordV1', f);
  for (const target of [join(outside, 'record.json'), normal.root + '/.sdd/context/../../foreign.json',
    join(normal.root, '.sdd', 'context', 'escape', 'record.json')]) {
    rejected(journalRecord(), 'JournalRecordV1', normal, { plannedPaths: [target] });
  }
});

const outcomeKinds = ['captured', 'uncaptured-warning', 'safe', 'unsafe', 'unavailable', 'recovered', 'no-op', 'cleaned', 'cleanup-warning'];
const outcomeCodes = ['ok', 'unsupported', 'validation-rejected', 'privacy-rejected', 'storage-failed',
  'integrity-failed', 'reconcile-failed', 'publication-failed', 'ownership-mismatch', 'expired', 'cleanup-failed', 'budget-exhausted'];
const outcome = (kind = 'unavailable') => ({ schemaVersion: 1, kind,
  reasonCode: ['captured', 'safe', 'recovered', 'cleaned'].includes(kind) ? 'ok' : 'unsupported', omission: false,
  ...structuredClone({ captured: { sequence: 0, synced: true },
    safe: { synced: true, reconciled: true, integrity: true, published: true },
    recovered: { coverage: 'complete', entries: [{ sourceSequences: [0], text: 'ordinary text', omission: false }],
      pointers: [{ opaqueId: 'pointer', reasonCode: 'expired' }] },
    cleaned: { expiredCount: 0, removedCount: 0, completed: true } }[kind] ?? {}) });
for (const kind of outcomeKinds) {
  check(`OR-OUTCOME-VALID-${kind}: closed result encoding admits without claiming operation execution`, () => {
    for (const omission of [false, true]) {
      const value = { ...outcome(kind), omission };
      if (kind === 'captured') value.sequence = omission ? Number.MAX_SAFE_INTEGER : 0;
      if (kind === 'cleaned') value.expiredCount = value.removedCount = omission ? Number.MAX_SAFE_INTEGER : 0;
      assert.deepEqual(admit(value, 'OutcomeV1'), value);
      assert.ok(Buffer.byteLength(JSON.stringify(value)) <= 8192);
    }
    assert.equal(existsSync(normal.target), false, 'outcome admission created a store file');
  });
}
check('OR-OUTCOME-CODES: fixed reasons diagnostics and pointer reasons admit without extra compatibility rules', () => {
  for (const kind of ['uncaptured-warning', 'unsafe', 'unavailable', 'cleanup-warning', 'no-op']) {
    for (const reasonCode of kind === 'no-op' ? outcomeCodes : outcomeCodes.slice(1)) {
      const value = { ...outcome(kind), reasonCode }; assert.deepEqual(admit(value, 'OutcomeV1'), value);
    }
  }
  for (const diagnostic of outcomeCodes) {
    const value = { ...outcome(), diagnostic };
    assert.deepEqual(admit(value, 'OutcomeV1'), value);
    const recovered = outcome('recovered'); recovered.pointers[0].reasonCode = diagnostic;
    assert.deepEqual(admit(recovered, 'OutcomeV1'), recovered);
  }
});
check('OR-OUTCOME-CLOSED: every per-kind field is required and foreign result fields reject', () => {
  for (const kind of outcomeKinds) {
    for (const field of Object.keys(outcome(kind))) {
      const value = outcome(kind); delete value[field]; rejected(value, 'OutcomeV1');
    }
    for (const field of ['owner', 'text', 'path', 'hash', 'stack', 'cause', 'deadline', 'entries', 'pointers',
      'coverage', 'sequence', 'synced', 'reconciled', 'integrity', 'published', 'expiredCount', 'removedCount', 'completed']) {
      if (!Object.hasOwn(outcome(kind), field)) rejected({ ...outcome(kind), [field]: true }, 'OutcomeV1');
    }
  }
  for (const value of [null, [], 'outcome', 1, true]) rejected(value, 'OutcomeV1');
});
check('OR-OUTCOME-FIELDS: exact versions discriminants booleans and fixed vocabulary reject malformed values', () => {
  for (const [field, invalid] of [
    ['schemaVersion', [0, 2, '1', null, true, [], {}]],
    ['kind', ['', 'unknown', ...outcomeKinds.map(kind => kind.toUpperCase()), null, 1, false, [], {}]],
    ['omission', [null, 0, 1, 'false', [], {}]],
    ['reasonCode', ['', 'unknown', ...outcomeCodes.map(code => code.toUpperCase()), journalSecret, normal.root, hash, null, 1, false, [], {}]],
    ['diagnostic', ['', 'unknown', ...outcomeCodes.map(code => code.toUpperCase()), journalSecret, normal.root, hash, '\ud800', null, 1, false, [], {}]],
  ]) for (const item of invalid) rejected({ ...outcome(), [field]: item }, 'OutcomeV1');
});
check('OR-OUTCOME-EVIDENCE: required success flags are literal true and counters are safe nonnegative integers', () => {
  for (const kind of ['captured', 'safe', 'recovered', 'cleaned']) {
    for (const reasonCode of outcomeCodes.slice(1)) rejected({ ...outcome(kind), reasonCode }, 'OutcomeV1');
  }
  for (const kind of ['uncaptured-warning', 'unsafe', 'unavailable', 'cleanup-warning']) {
    rejected({ ...outcome(kind), reasonCode: 'ok' }, 'OutcomeV1');
  }
  for (const [kind, fields] of [['captured', ['synced']], ['safe', ['synced', 'reconciled', 'integrity', 'published']], ['cleaned', ['completed']]]) {
    for (const field of fields) for (const item of [false, null, 0, 1, 'true', [], {}]) {
      rejected({ ...outcome(kind), [field]: item }, 'OutcomeV1');
    }
  }
  for (const [kind, fields] of [['captured', ['sequence']], ['cleaned', ['expiredCount', 'removedCount']]]) {
    for (const field of fields) for (const item of [-1, 0.5, Number.MAX_SAFE_INTEGER + 1, '0', null, true, [], {}]) {
      rejected({ ...outcome(kind), [field]: item }, 'OutcomeV1');
    }
  }
});
check('OR-OUTCOME-RECOVERY: coverage source endpoints empty lists and opaque pointer byte limits admit', () => {
  for (const coverage of ['complete', 'partial', 'unavailable']) {
    const value = outcome('recovered'); value.coverage = coverage;
    value.entries[0].sourceSequences = [0, Number.MAX_SAFE_INTEGER];
    value.entries[0].text = ''; value.entries[0].omission = true;
    for (const opaqueId of ['p', 'x'.repeat(1024), '🙂'.repeat(256)]) {
      value.pointers[0].opaqueId = opaqueId; assert.deepEqual(admit(value, 'OutcomeV1'), value);
    }
    value.entries = []; value.pointers = []; assert.deepEqual(admit(value, 'OutcomeV1'), value);
  }
});
check('OR-OUTCOME-RECOVERY-SHAPE: nested entry and pointer closures scalars and arrays reject malformed values', () => {
  for (const [field, invalid] of [['coverage', ['', 'unknown', 'Complete', 'Partial', 'Unavailable', null, 1, [], {}]],
    ['entries', [null, {}, 'entries', 1]], ['pointers', [null, {}, 'pointers', 1]]]) {
    for (const item of invalid) rejected({ ...outcome('recovered'), [field]: item }, 'OutcomeV1');
  }
  for (const [list, invalidFields] of [['entries', {
    sourceSequences: [[], null, {}, 'source', [null], [-1], [0.5], [Number.MAX_SAFE_INTEGER + 1], ['0'], [true], [[]]],
    text: [null, 1, false, [], {}, '\ud800'], omission: [null, 0, 'false', [], {}] }], ['pointers', {
    opaqueId: ['', 'x'.repeat(1025), '🙂'.repeat(256) + 'x', '\ud800', null, 1, false, [], {}],
    reasonCode: ['', 'unknown', 'Expired', journalSecret, normal.root, hash, null, 1, false, [], {}] }]]) {
    for (const item of [null, [], 'entry', 1]) {
      const value = outcome('recovered'); value[list] = [item]; rejected(value, 'OutcomeV1');
    }
    for (const field of Object.keys(invalidFields)) {
      const missing = outcome('recovered'); delete missing[list][0][field]; rejected(missing, 'OutcomeV1');
      for (const item of invalidFields[field]) {
        const value = outcome('recovered'); value[list][0][field] = item; rejected(value, 'OutcomeV1');
      }
    }
    for (const field of ['extra', 'owner', 'path', 'hash', 'originalReceipts']) {
      const value = outcome('recovered'); value[list][0][field] = true; rejected(value, 'OutcomeV1');
    }
  }
});
check('OR-OUTCOME-RECOVERY-PRIVACY: shared redaction preserves prior omission and masks all six families', () => {
  for (const [, raw] of journalSensitive) {
    const clean = journalRedact(raw, context('OutcomeV1').deadline).text;
    for (const omission of [false, true]) {
      const value = outcome('recovered'); value.entries[0].text = clean; value.entries[0].omission = value.omission = omission;
      assert.deepEqual(admit(value, 'OutcomeV1'), value);
      value.entries[0].text = raw;
      const expected = structuredClone(value); expected.entries[0].text = clean;
      expected.entries[0].omission = expected.omission = true;
      assert.deepEqual(admit(value, 'OutcomeV1'), expected);
      assert.equal(expected.entries[0].text.includes(journalSecret), false);
    }
  }
  const invalid = outcome('recovered'); invalid.entries[0].text = `${journalKey}="unterminated`;
  rejected(invalid, 'OutcomeV1');
});
check('OR-OUTCOME-BUDGET: complete escaped UTF8 envelope admits 8192 bytes and rejects 8193', () => {
  for (const unit of ['界', '"\n']) {
    const value = outcome('recovered'); value.diagnostic = 'ok'; value.entries[0].text = '';
    const available = 8192 - Buffer.byteLength(JSON.stringify(value));
    const encoded = Buffer.byteLength(JSON.stringify(unit)) - 2;
    value.entries[0].text = unit.repeat(Math.floor(available / encoded)) + 'x'.repeat(available % encoded);
    assert.equal(Buffer.byteLength(JSON.stringify(value)), 8192);
    assert.deepEqual(admit(value, 'OutcomeV1'), value);
    value.entries[0].text += 'x'; assert.equal(Buffer.byteLength(JSON.stringify(value)), 8193);
    rejected(value, 'OutcomeV1');
  }
});

// Synthetic core-owned confirmation controls, independent of the registry JSON.
const confirmedOwners = [{ ...normal.owner }, { ...sha1.owner }];
const ownerRegistry = () => ({ schemaVersion: 1, entries: [registryEntry(),
  { ...registryEntry(sha1), registrationId: 'foreign-registration' }], maxObservedUtc: '2026-09-29T00:00:00Z' });
check('OR-REGISTRY-VALID: independently confirmed local and foreign closed entries admit every scheduler state', () => {
  for (const schedulerState of ['enabled', 'disabled', 'failed']) {
    for (const registrationId of ['r', 'x'.repeat(1024), '🙂'.repeat(256)]) {
      const value = ownerRegistry(); value.entries.forEach(entry => { entry.schedulerState = schedulerState; });
      value.entries[1].registrationId = registrationId; value.entries[1].checkedAtUtc = value.maxObservedUtc = '2026-09-29T00:00:00.123Z';
      const before = JSON.stringify(confirmedOwners);
      assert.deepEqual(admit(value, 'OwnerRegistryV1', { confirmedOwners }), value);
      assert.equal(JSON.stringify(confirmedOwners), before, 'registry admission mutated trusted confirmation');
    }
  }
  const value = ownerRegistry(); value.entries = [];
  assert.deepEqual(admit(value, 'OwnerRegistryV1', { confirmedOwners: [] }), value);
  assert.equal(existsSync(normal.target), false); assert.equal(existsSync(sha1.target), false);
});
check('OR-REGISTRY-CLOSED: registry and each nested locator require closed fields', () => {
  for (const field of Object.keys(ownerRegistry())) {
    const value = ownerRegistry(); delete value[field]; rejected(value, 'OwnerRegistryV1', normal, { confirmedOwners });
  }
  for (const field of ['confirmedOwners', 'text', 'owner', 'deadline', 'plannedPaths', 'extra']) {
    rejected({ ...ownerRegistry(), [field]: confirmedOwners }, 'OwnerRegistryV1', normal, { confirmedOwners });
  }
  for (const value of [null, [], 'registry', 1, true]) rejected(value, 'OwnerRegistryV1', normal, { confirmedOwners });
  for (const field of Object.keys(registryEntry())) {
    const value = ownerRegistry(); delete value.entries[1][field]; rejected(value, 'OwnerRegistryV1', normal, { confirmedOwners });
  }
  for (const field of ['schemaVersion', 'text', 'confirmed', 'path', 'extra']) {
    const value = ownerRegistry(); value.entries[1][field] = true; rejected(value, 'OwnerRegistryV1', normal, { confirmedOwners });
  }
});
check('OR-REGISTRY-FIELDS: root and foreign entry scalar bounds UTC states and array shapes reject', () => {
  for (const [field, invalid] of [['schemaVersion', [0, 2, '1', null, true, [], {}]], ['entries', [null, {}, 'entries', 1]],
    ['maxObservedUtc', ['', null, 1, false, [], {}, '2026-02-30T00:00:00Z', '2026-09-29T24:00:00Z', '2026-09-29T00:00:00+00:00']]]) {
    for (const item of invalid) rejected({ ...ownerRegistry(), [field]: item }, 'OwnerRegistryV1', normal, { confirmedOwners });
  }
  for (const item of [null, [], 'entry', 1]) {
    const value = ownerRegistry(); value.entries = [item]; rejected(value, 'OwnerRegistryV1', normal, { confirmedOwners });
  }
  for (const [field, invalid] of [['registrationId', ['', null, 1, false, [], {}, 'x'.repeat(1025), '🙂'.repeat(256) + 'x', '\ud800']],
    ['schedulerState', ['', 'unknown', 'Enabled', 'Disabled', 'Failed', null, 1, false, [], {}]],
    ['checkedAtUtc', ['', null, 1, false, [], {}, '2026-02-30T00:00:00Z', '2026-09-29T24:00:00Z', '2026-09-29T00:00:00+00:00']]]) {
    for (const item of invalid) {
      const value = ownerRegistry(); value.entries[1][field] = item; rejected(value, 'OwnerRegistryV1', normal, { confirmedOwners });
    }
  }
});
check('OR-REGISTRY-OWNER: foreign nested owner closure and every unconfirmed tuple component reject', () => {
  for (const owner of [null, [], 'owner', 1]) {
    const value = ownerRegistry(); value.entries[1].owner = owner; rejected(value, 'OwnerRegistryV1', normal, { confirmedOwners });
  }
  for (const field of Object.keys(sha1.owner)) {
    const value = ownerRegistry(); delete value.entries[1].owner[field]; rejected(value, 'OwnerRegistryV1', normal, { confirmedOwners });
  }
  for (const [field, item] of [['schemaVersion', 2], ['sddRoot', normal.root], ['worktreeRoot', normal.root],
    ['gitDirectory', normal.owner.gitDirectory], ['featureId', 'foreign'], ['host', 'claude'], ['sessionId', 'foreign'], ['confirmed', true]]) {
    const value = ownerRegistry(); value.entries[1].owner[field] = item; rejected(value, 'OwnerRegistryV1', normal, { confirmedOwners });
  }
});
check('OR-REGISTRY-TRUST: missing malformed or self-asserted confirmation cannot authorize a registry', () => {
  rejected(ownerRegistry(), 'OwnerRegistryV1');
  for (const list of [null, {}, 'owners', 1, [], [{ ...normal.owner }], [null], [[], {}],
    [{ ...sha1.owner, extra: true }], [{ ...sha1.owner, schemaVersion: 2 }]]) {
    rejected(ownerRegistry(), 'OwnerRegistryV1', normal, { confirmedOwners: list });
  }
  rejected({ ...ownerRegistry(), confirmedOwners }, 'OwnerRegistryV1');
  const value = ownerRegistry();
  value.entries[1].confirmedOwners = [{ ...sha1.owner }]; rejected(value, 'OwnerRegistryV1');
});
check('OR-REGISTRY-UNIQUE: identical or conflicting canonical owner tuples and duplicate IDs reject', () => {
  for (const change of [{}, { registrationId: 'second', schedulerState: 'disabled' },
    { registrationId: 'second', storeRoot: join(sha1.root, '.sdd', 'context') }]) {
    const value = ownerRegistry(); value.entries = [registryEntry(), { ...registryEntry(), ...change }];
    rejected(value, 'OwnerRegistryV1', normal, { confirmedOwners });
  }
  const aliases = ownerRegistry(); aliases.entries = [registryEntry(), { ...registryEntry(), registrationId: 'alias' }];
  for (const field of ['sddRoot', 'worktreeRoot', 'gitDirectory']) aliases.entries[1].owner[field] += '/';
  rejected(aliases, 'OwnerRegistryV1', normal, { confirmedOwners });
  const duplicateId = ownerRegistry(); duplicateId.entries[1].registrationId = duplicateId.entries[0].registrationId;
  rejected(duplicateId, 'OwnerRegistryV1', normal, { confirmedOwners });
});
check('OR-REGISTRY-STORE: each locator binds exactly to its confirmed owner context store', () => {
  for (const storeRoot of [null, 1, [], {}, sha1.root, sha1.target, join(sha1.root, '.git'),
    join(sha1.root, '.sdd', 'context', 'child'), registryEntry().storeRoot, outside,
    join(normal.root, '.sdd', 'context', 'escape'), sha1.root + '/.sdd/context/../../outside']) {
    const value = ownerRegistry(); value.entries[1].storeRoot = storeRoot;
    rejected(value, 'OwnerRegistryV1', normal, { confirmedOwners });
  }
});
check('OR-SHARED-GUARDS: both new types retain JSON deadline Git and planned-path rejection', () => {
  for (const [type, value, extra] of [['OutcomeV1', outcome(), {}], ['OwnerRegistryV1', ownerRegistry(), { confirmedOwners }]]) {
    const source = JSON.stringify(value);
    for (const raw of [source.slice(0, -1), source.replace('"schemaVersion":1', '"schemaVersion":1,"schema\\u0056ersion":1')]) {
      rejected(raw, type, normal, extra, true);
    }
    rejected(value, type, normal, { ...extra, deadline: performance.now() - 1 });
    for (const f of [missingIgnore, negatedIgnore, tracked, brokenGit]) rejected(value, type, f, extra);
    for (const target of [join(outside, 'result.json'), normal.root + '/.sdd/context/../../foreign.json',
      join(normal.root, '.sdd', 'context', 'escape', 'result.json')]) {
      rejected(value, type, normal, { ...extra, plannedPaths: [target] });
    }
  }
});
